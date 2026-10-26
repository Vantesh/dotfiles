"""Guarded resume, Zswap and sleep policy; boot-artifact rebuilding remains deferred."""

import math
import os
import re
import stat
import subprocess
import sys
from pathlib import Path

from .hibernation_swap import (
    ETC,
    SWAP_FILE,
    SYS,
    BtrfsDevice,
    fstab_entries,
    memory_kib,
    swap_units,
)

SHARE = Path("/usr/share")


def persistent_cmdline(parser: Path) -> str:
    return subprocess.run(
        [sys.executable, "-I", "-B", str(parser), "hibernation"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def request_rebuild(state: Path) -> None:
    info = state.lstat()
    if (
        not state.is_absolute()
        or not stat.S_ISDIR(info.st_mode)
        or info.st_uid != int(os.environ["SUDO_UID"])
        or info.st_mode & 0o022
    ):
        raise ValueError("Rebuild state requires a safe directory owned by the regular account.")
    descriptor = os.open(
        state / "initramfs.pending", os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600
    )
    with os.fdopen(descriptor, "w") as stream:
        info = os.fstat(stream.fileno())
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_nlink != 1
            or info.st_uid not in (0, int(os.environ["SUDO_UID"]))
        ):
            raise ValueError("Unsafe deferred initramfs marker.")
        os.fchown(stream.fileno(), int(os.environ["SUDO_UID"]), int(os.environ["SUDO_GID"]))
        os.fchmod(stream.fileno(), 0o600)


def configure_resume(device: BtrfsDevice, state: Path, work: Path, parser: Path) -> None:
    from lib.policy_files import publish_config, rollback_configs, snapshot_config

    directory = ETC / "limine-entry-tool.d"
    directory.mkdir(mode=0o755, exist_ok=True)
    defaults = directory / "01-default.conf"
    managed = directory / "50-hibernation.conf"
    paths = (
        sorted((SHARE / "limine-entry-tool.d").glob("*.conf"))
        + [ETC / "limine-entry-tool.conf"]
        + sorted(set(directory.glob("*.conf")) | {defaults, managed})
        + [ETC / "default/limine"]
    )
    features = {defaults, managed, directory / "20-quiet-boot.conf", directory / "zswap.conf"}
    baseline = any(
        re.search(
            r"(?m)^\s*KERNEL_CMDLINE\[default\]\s*" + (r"=" if path in features else r"\+?="),
            path.read_text(),
        )
        for path in paths
        if path.exists()
    )
    if not baseline or defaults.is_file():
        config = snapshot_config(defaults, work / "defaults.before")
        candidate = work / "defaults.next"
        content = config.backup.read_text()
        if not baseline:
            original = (ETC / "kernel/cmdline").read_text().strip()
            if not original or "\n" in original:
                raise ValueError(
                    "No single-line persistent Limine baseline; configure it manually."
                )
            content = 'KERNEL_CMDLINE[default]= "' + original.replace('"', r"\"") + '"\n' + content
        _ = candidate.write_text(content)
        _ = subprocess.run(
            [sys.executable, "-I", "-B", str(parser), "deduplicate-file", str(candidate)],
            check=True,
        )
        if config.original is None or candidate.read_bytes() != config.backup.read_bytes():
            request_rebuild(state)
            _ = publish_config(config, candidate.read_bytes())
    offset = subprocess.run(
        ["btrfs", "inspect-internal", "map-swapfile", "-r", str(SWAP_FILE)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if not re.fullmatch(r"[0-9]+", offset):
        raise ValueError("Invalid final Btrfs resume offset.")
    config = snapshot_config(managed, work / "resume.before")
    candidate = work / "resume.next"
    _ = candidate.write_bytes(config.backup.read_bytes())
    params = f"hibernate.compressor=lz4 resume=UUID={device.uuid} resume_offset={offset}"
    _ = subprocess.run(
        [
            sys.executable,
            "-I",
            "-B",
            str(parser),
            "fragment-file",
            managed.name,
            str(candidate),
            params,
        ],
        check=True,
    )
    try:
        changed = config.original is None or candidate.read_bytes() != config.backup.read_bytes()
        if changed:
            request_rebuild(state)
            _ = publish_config(config, candidate.read_bytes())
        # Re-evaluate precedence after publication: later defaults must not
        # suppress this resume owner while the workflow reports completion.
        _ = persistent_cmdline(parser)
    except BaseException:
        rollback_configs([config])
        raise
    if changed:
        print("Configured managed Btrfs swapfile resume.")


def configure_zswap(state: Path, work: Path, parser: Path) -> None:
    from lib.policy_files import publish_config, rollback_configs, snapshot_config

    previous = persistent_cmdline(parser)
    fragment = ETC / "limine-entry-tool.d/zswap.conf"
    if (
        any(token.startswith("zswap.") for token in previous.split())
        or fragment.exists()
        or fragment.is_symlink()
        or memory_kib() < 30 * 1024**2
    ):
        return
    if any((SYS / "block").glob("zram[0-9]*")):
        return
    active = subprocess.run(
        ["swapon", "--show=NAME", "--noheadings", "--raw"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    if any(re.fullmatch(r"/dev/zram[0-9]+", path) for path in active):
        return
    for base in (ETC, Path("/run"), Path("/usr/lib")):
        paths = [
            base / "systemd/zram-generator.conf",
            *sorted((base / "systemd/zram-generator.conf.d").glob("*.conf")),
        ]
        if any(path.exists() or path.is_symlink() for path in paths):
            return
    if any(
        (ETC / path).exists() or (ETC / path).is_symlink()
        for path in ("default/zramswap", "default/zram-config", "conf.d/zram")
    ):
        return
    for unit, status in swap_units(include_services=True):
        if unit.endswith("@.service"):
            continue
        if unit.endswith(".swap"):
            path = subprocess.run(
                ["systemctl", "show", "--property=What", "--value", unit],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            if re.fullmatch(r"/dev/zram[0-9]+", path):
                return
        elif "zram" in unit and status in (
            "enabled",
            "enabled-runtime",
            "linked",
            "linked-runtime",
            "generated",
        ):
            return
    if any(
        re.fullmatch(r"/dev/zram[0-9]+", source)
        for source, _, kind, _ in fstab_entries()
        if kind == "swap"
    ):
        return
    config = snapshot_config(fragment, work / "zswap.before")
    try:
        request_rebuild(state)
        _ = publish_config(
            config, b'KERNEL_CMDLINE[default]+=" zswap.enabled=1 zswap.compressor=lz4"\n'
        )
        updated = persistent_cmdline(parser).split()
        retained = [token for token in updated if not token.startswith("zswap.")]
        if (
            updated.count("zswap.enabled=1") != 1
            or updated.count("zswap.compressor=lz4") != 1
            or len(updated) != len(retained) + 2
            or retained != previous.split()
        ):
            raise ValueError("Zswap verification changed unrelated persistent arguments.")
    except BaseException:
        rollback_configs([config])
        raise
    print("Configured Zswap for next boot; reboot required for activation.")


def configure_sleep(work: Path) -> None:
    from lib.policy_files import publish_config, snapshot_config

    files = {
        "systemd/sleep.conf.d/hibernation.conf": "[Sleep]\nAllowSuspend=yes\nAllowHibernation=yes\nAllowSuspendThenHibernate=yes\nHibernateDelaySec=30min\nAllowHybridSleep=yes\nHibernateMode=platform shutdown\nHibernateOnACPower=yes\n",
        "systemd/logind.conf.d/hibernation.conf": "[Login]\nHandleSuspendKey=ignore\nHandleHibernateKey=ignore\nHandleLidSwitch=suspend-then-hibernate\n",
        "udev/rules.d/90-disable-usb-wake.rules": '# Disable wakeup on USB host controllers, independent of ACPI device names.\nACTION=="add|change", SUBSYSTEM=="pci", ATTR{class}=="0x0c03*", TEST=="power/wakeup", ATTR{power/wakeup}="disabled"\n',
    }
    if math.ceil(memory_kib() / 1024**2) > 30:
        files["tmpfiles.d/hibernation_image_size.conf"] = (
            "#    Path                   Mode UID  GID  Age Argument\nw    /sys/power/image_size  -    -    -    -   0\n"
        )
    for index, (name, content) in enumerate(files.items()):
        path = ETC / name
        path.parent.mkdir(parents=True, mode=0o755, exist_ok=True)
        config = snapshot_config(path, work / f"sleep-{index}")
        changed = publish_config(config, content.encode(), mode=0o644)
        if changed:
            print(f"Configured {path}.")
    _ = subprocess.run(["udevadm", "control", "--reload-rules"], check=True)
    _ = subprocess.run(
        [
            "udevadm",
            "trigger",
            "--action=change",
            "--subsystem-match=pci",
            "--attr-match=class=0x0c03*",
        ],
        check=True,
    )
    _ = subprocess.run(["udevadm", "settle"], check=True)
