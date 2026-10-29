"""Persistent Limine settings and guarded publication of managed boot configuration."""

import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import cast

from .hibernation_policy import request_rebuild
from .policy_files import publish_config, snapshot_config

ETC = Path("/etc")
SHARE = Path("/usr/share")


def config_files() -> list[Path]:
    return (
        sorted((SHARE / "limine-entry-tool.d").glob("*.conf"))
        + [ETC / "limine-entry-tool.conf"]
        + sorted((ETC / "limine-entry-tool.d").glob("*.conf"))
        + [ETC / "default/limine"]
    )


def read_limine_value(key: str) -> str:
    value = ""
    for path in (
        [ETC / "default/limine"] if key == "ENABLE_ENROLL_LIMINE_CONFIG" else config_files()
    ):
        try:
            text = path.read_text()
        except FileNotFoundError:
            continue
        for line in text.splitlines():
            match = re.match(rf"^\s*{re.escape(key)}\s*=\s*(.*)$", line)
            if match:
                value = match[1].removeprefix('"').removesuffix('"')
    return value


def boot_directory() -> Path:
    configured = read_limine_value("ESP_PATH")
    if configured and not Path(configured).is_absolute():
        raise ValueError("Limine ESP_PATH must be an absolute mount path.")
    paths = (
        [Path(configured)]
        if configured
        else [Path(p) for p in ("/efi", "/boot", "/boot/efi", "/limine")]
    )
    for path in paths:
        result = subprocess.run(
            ["findmnt", "-rn", "-o", "FSTYPE", "--mountpoint", str(path)],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip() == "vfat":
            return path
        if result.returncode not in (0, 1):
            result.check_returncode()
    raise ValueError(
        "Limine FAT32 boot partition is not mounted; mount /boot or configure ESP_PATH."
    )


def parser_command(parser: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            [sys.executable, "-I", "-B", str(parser), *args],
            check=True,
            capture_output=True,
            text=True,
        )
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        return result.stdout.strip()
    except subprocess.CalledProcessError as error:
        diagnostic = cast("str | None", error.stderr)
        if diagnostic:
            error.add_note(diagnostic.strip())
        raise


def validate_mkinitcpio_options() -> None:
    pending = False
    for arg in read_limine_value("MKINITCPIO_UKI_OPTIONS").split():
        if pending:
            if arg.startswith("-"):
                raise ValueError(f"MKINITCPIO_UKI_OPTIONS is missing a value before {arg}.")
            pending = False
        elif arg in ("--verbose", "--quiet", "--nocolor", "-v", "-q", "-n"):
            continue
        elif arg in ("--compress", "--splash"):
            pending = True
        elif re.fullmatch(r"--(?:compress|splash)=.+", arg):
            continue
        else:
            raise ValueError(
                f"Unsupported MKINITCPIO_UKI_OPTIONS argument: {arg}; review managed hook/unlock requirements."
            )
    if pending:
        raise ValueError("MKINITCPIO_UKI_OPTIONS is missing an option value.")


def write_dropin(name: str, content: str, state: Path) -> None:
    destination = ETC / "mkinitcpio.conf.d" / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    _ = subprocess.run(["bash", "-n"], input=content, text=True, check=True, capture_output=True)
    with tempfile.TemporaryDirectory(prefix="chezmoi-initramfs-") as temporary:
        config = snapshot_config(destination, Path(temporary) / "before")
        data = (content.rstrip("\n") + "\n").encode()
        if config.original is not None and config.backup.read_bytes() == data:
            return
        request_rebuild(state)
        _ = publish_config(config, data, mode=0o644)


def configure_limine_settings(settings: dict[str, str], state: Path) -> None:
    path = ETC / "default/limine"
    with tempfile.TemporaryDirectory(prefix="chezmoi-limine-") as temporary:
        config = snapshot_config(path, Path(temporary) / "before")
        text = config.backup.read_text()
        for key, value in settings.items():
            if read_limine_value(key) == value:
                continue
            pattern = rf"(?m)^\s*#?\s*{re.escape(key)}\s*=.*$"
            replacement = f'{key}="{value}"'
            text = (
                re.sub(pattern, lambda _, value=replacement: value, text)
                if re.search(pattern, text)
                else text + f"\n{replacement}\n"
            )
        if text.encode() != config.backup.read_bytes():
            request_rebuild(state)
            _ = publish_config(config, text.encode())


def ensure_limine_defaults(parser: Path, state: Path) -> None:
    directory = ETC / "limine-entry-tool.d"
    directory.mkdir(parents=True, exist_ok=True)
    default = directory / "01-default.conf"
    feature_files = {
        directory / name
        for name in ("01-default.conf", "20-quiet-boot.conf", "50-hibernation.conf", "zswap.conf")
    }
    baseline = False
    for path in config_files():
        try:
            content = path.read_text()
        except FileNotFoundError:
            continue
        operator = "=" if path in feature_files else r"\+?="
        if re.search(rf"(?m)^\s*KERNEL_CMDLINE\[default\]\s*{operator}", content):
            baseline = True
    initial = ""
    if not baseline:
        value = (ETC / "kernel/cmdline").read_text().rstrip("\n")
        if not value.strip() or "\n" in value:
            raise ValueError(
                "No single-line persistent kernel command line; review /etc/kernel/cmdline or Limine defaults."
            )
        initial = 'KERNEL_CMDLINE[default]= "' + value.replace('"', '\\"') + '"\n'
    if not initial and not default.exists():
        return
    with tempfile.TemporaryDirectory(prefix="chezmoi-defaults-") as temporary:
        work = Path(temporary)
        config = snapshot_config(default, work / "before")
        stage = work / "stage"
        _ = stage.write_bytes(initial.encode() + config.backup.read_bytes())
        _ = parser_command(parser, "deduplicate-file", str(stage))
        if stage.read_bytes() != config.backup.read_bytes():
            request_rebuild(state)
            _ = publish_config(config, stage.read_bytes())


def publish_limine_fragment(parser: Path, state: Path, name: str, params: str) -> None:
    if name not in ("20-quiet-boot.conf", "50-hibernation.conf"):
        raise ValueError("Unsupported managed Limine feature fragment.")
    path = ETC / "limine-entry-tool.d" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="chezmoi-feature-") as temporary:
        work = Path(temporary)
        config = snapshot_config(path, work / "before")
        stage = work / "stage"
        _ = stage.write_bytes(config.backup.read_bytes())
        _ = parser_command(parser, "fragment-file", name, str(stage), params)
        if stage.read_bytes() != config.backup.read_bytes():
            request_rebuild(state)
            _ = publish_config(config, stage.read_bytes())


def configure_quiet_boot(parser: Path, state: Path, *, plymouth: bool) -> None:
    ensure_limine_defaults(parser, state)
    params = "quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.cur_default=1 systemd.tpm2_measured_os=0"
    if plymouth:
        params += " splash"
    publish_limine_fragment(parser, state, "20-quiet-boot.conf", params)
