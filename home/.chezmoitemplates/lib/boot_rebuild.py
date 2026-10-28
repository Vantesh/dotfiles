"""Commit pending boot changes only after verifying the deployed artifacts and signatures."""

import errno
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import time
from contextlib import suppress
from pathlib import Path
from typing import BinaryIO, cast

from loguru import logger

from .limine_config import boot_directory, read_limine_value
from .policy_files import same_state
from .secure_boot import check_signing_key
from .verify_limine_rebuild import inventory, verify, verify_enrollment

ENROLL_HOOK = Path("/etc/boot/hooks/post.d/90-limine-enroll-config")
MAX_OUTPUT = 32 * 1024 * 1024


def checked_limine_command(command: list[str]) -> str:
    # Limine package helpers have reported failure text with status zero. Keep
    # this domain-specific check alongside artifact verification, with bounded IO.
    env = os.environ.copy()
    env.update(LC_ALL="C", NO_COLOR="1", TERM="dumb")
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, start_new_session=True
    ) as process:
        data = bytearray()
        try:
            if process.stdout is None:
                raise ValueError("Cannot inspect Limine command diagnostics.")
            stream = cast("BinaryIO", process.stdout)
            while chunk := stream.read(65536):
                if len(data) + len(chunk) > MAX_OUTPUT:
                    raise ValueError(
                        "Limine diagnostics exceeded 32 MiB; rebuild request preserved."
                    )
                data.extend(chunk)
            status = process.wait()
        except BaseException:
            # The shell leader can exit while a descendant still owns stdout or
            # writes boot artifacts. Clean up its session independently of poll().
            blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
            try:
                with suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGTERM)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    _ = process.poll()
                    try:
                        os.killpg(process.pid, 0)
                    except ProcessLookupError:
                        break
                    time.sleep(0.05)
                with suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGKILL)
                _ = process.wait()
            finally:
                _ = signal.pthread_sigmask(signal.SIG_SETMASK, blocked)
            raise
    output = data.decode(errors="replace")
    logger.debug("{} diagnostic:\n{}", command[0], output.rstrip())
    if status:
        raise subprocess.CalledProcessError(status, command, stderr=output)
    if re.search(
        r"error:|fatal:|failed|exception|traceback|usage:|unsupported|not supported|downgrade skipped|skipping (upgrade|installation)|no kernel found|no Limine EFI binary|not using UEFI|errors were encountered",
        output,
        re.IGNORECASE,
    ):
        raise subprocess.CalledProcessError(1, command, stderr=output)
    return output


def boot_identity(boot: Path) -> tuple[str, ...]:
    fields = subprocess.run(
        ["findmnt", "-rn", "-o", "TARGET,SOURCE,FSTYPE,UUID", "--mountpoint", str(boot)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    if (
        len(fields) != 4
        or fields[0] != str(boot)
        or not Path(fields[1]).is_absolute()
        or fields[2] != "vfat"
    ):
        raise ValueError("Cannot verify one mounted FAT32 ESP and its device/UUID identity.")
    return tuple(fields)


def verify_signatures(paths: list[Path]) -> None:
    # sbctl 0.18 returns zero for unsigned files; positive per-file JSON results
    # are required. https://github.com/Foxboron/sbctl/blob/0.18/cmd/sbctl/verify.go
    command = ["sbctl", "--json", "verify", *(str(path) for path in paths)]
    output = subprocess.run(command, check=True, capture_output=True, text=True).stdout
    result = cast("object", json.loads(output))
    if not isinstance(result, list):
        raise ValueError("sbctl did not return per-file signature verification results.")
    records = cast("list[object]", result)
    verified: set[str] = set()
    for value in records:
        if not isinstance(value, dict):
            raise ValueError("Invalid sbctl signature verification result.")
        record = cast("dict[str, object]", value)
        name, signed = record.get("file_name"), record.get("is_signed")
        if not isinstance(name, str) or type(signed) is not int or signed != 1 or name in verified:
            raise ValueError(
                "A managed boot artifact is unsigned, missing, or not positively verified by sbctl."
            )
        verified.add(name)
    if verified != {str(path) for path in paths}:
        raise ValueError("sbctl did not verify every managed EFI/UKI artifact.")


def rebuild_boot(state: Path) -> None:
    info = state.lstat()
    if (
        not state.is_absolute()
        or not stat.S_ISDIR(info.st_mode)
        or info.st_uid != int(os.environ["SUDO_UID"])
        or info.st_mode & 0o022
    ):
        raise ValueError("Rebuild state requires a safe directory owned by the regular account.")
    pending = state / "initramfs.pending"
    requested = pending.lstat()
    if (
        not stat.S_ISREG(requested.st_mode)
        or requested.st_nlink != 1
        or requested.st_uid != int(os.environ["SUDO_UID"])
    ):
        raise ValueError("Unsafe initramfs rebuild request; preserved without rebuilding.")
    for command in (
        "limine",
        "mkinitcpio",
        "limine-install",
        "limine-mkinitcpio",
        "pacman",
        "lsinitcpio",
    ):
        if shutil.which(command) is None:
            raise FileNotFoundError(
                errno.ENOENT, "Required rebuild command missing; request preserved", command
            )
    boot = boot_directory()
    identity = boot_identity(boot)
    uki, fallback = read_limine_value("ENABLE_UKI"), read_limine_value("MKINITCPIO_FALLBACK")
    expected = inventory(fallback, uki)
    enroll = read_limine_value("ENABLE_ENROLL_LIMINE_CONFIG") == "yes"
    if enroll:
        helper = shutil.which("limine-enroll-config")
        if (
            helper is None
            or not os.access(ENROLL_HOOK, os.X_OK)
            or ENROLL_HOOK.read_bytes() != Path(helper).read_bytes()
        ):
            raise ValueError(
                "Required Limine enrollment post-hook is missing or differs from the installed helper."
            )
        output = subprocess.run(
            ["sbctl", "setup", "--print-state", "--json"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        setup = cast("dict[str, object]", json.loads(output))
        if setup.get("installed") is not True:
            raise ValueError(
                "sbctl signing setup is unavailable; complete Secure Boot setup before rebuilding."
            )
        check_signing_key()
    _ = checked_limine_command(["limine-install", "--no-efi-register"])
    if boot_directory() != boot or boot_identity(boot) != identity:
        raise ValueError("ESP identity changed after Limine deployment; rebuild request preserved.")
    output = checked_limine_command(["limine-mkinitcpio"])
    if boot_directory() != boot or boot_identity(boot) != identity:
        raise ValueError(
            "ESP identity changed during initramfs generation; rebuild request preserved."
        )
    uki, fallback = read_limine_value("ENABLE_UKI"), read_limine_value("MKINITCPIO_FALLBACK")
    efi = verify(boot.resolve(), expected, output, fallback, uki)
    if enroll:
        # Package post-hooks already enroll the final checksum and then sign.
        # Read and verify their result; never reopen or rewrite the signed image.
        efi.append(verify_enrollment(boot.resolve()))
        verify_signatures(efi)
    if boot_identity(boot) != identity or not same_state(requested, pending.lstat()):
        raise ValueError(
            "ESP identity or rebuild request changed during verification; request preserved."
        )
    pending.unlink()
    print("Verified boot artifacts and completed the pending initramfs rebuild.")
