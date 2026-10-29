"""Systemd mkinitcpio hooks and verified conversion of installer root unlocking."""

import re
import subprocess
import tempfile
from pathlib import Path

from .hibernation_policy import request_rebuild
from .hibernation_swap import BtrfsDevice, inspect_btrfs_device
from .limine_config import ETC, parser_command, validate_mkinitcpio_options, write_dropin
from .policy_files import PolicyFile, publish_config, rollback_configs, snapshot_config

SYS = Path("/sys")
DEV = Path("/dev")
LIB = Path("/usr/lib")
KEYFILE = Path("/crypto_keyfile.bin")
HEADER = "# Managed systemd base; snapshot hooks belong to Snapper.\n"
OBSOLETE = {"udev", "encrypt", "keymap", "consolefont", "resume", "btrfs-overlayfs"}


def read_hooks(mode: str = "current", candidate: str = "") -> list[str]:
    managed = ETC / "mkinitcpio.conf.d/00-chezmoi-systemd.conf"
    paths = set((ETC / "mkinitcpio.conf.d").glob("*.conf")) | {managed}
    ordered = (
        subprocess.run(
            ["sort", "-zVu"],
            input=b"\0".join(str(path).encode() for path in paths) + b"\0",
            check=True,
            capture_output=True,
            env={"PATH": "/usr/bin:/bin", "LC_ALL": "C.UTF-8"},
        )
        .stdout.rstrip(b"\0")
        .decode()
        .split("\0")
    )
    content = (ETC / "mkinitcpio.conf").read_text()
    for name in ordered:
        path = Path(name)
        if path == managed:
            if mode == "base":
                break
            if mode == "candidate":
                content += "\n" + candidate
                continue
        try:
            content += "\n" + path.read_text()
        except FileNotFoundError:
            continue
    # mkinitcpio configuration is Bash. Evaluate the trusted installed configs
    # together, exactly as mkinitcpio does, rather than inventing a shell parser.
    evaluation = """set -euo pipefail
source /dev/stdin
if [[ "${HOOKS@a}" != *a* ]]; then read -r -a HOOKS <<< "${HOOKS:-}"; fi
printf '%s\\n' "${HOOKS[*]}"
printf '%s\\n' "${FILES[*]-}"
"""
    output = subprocess.run(
        ["bash", "-c", evaluation], input=content, check=True, capture_output=True, text=True
    ).stdout.splitlines()
    hooks = output[0].split() if output else []
    if mode == "unlock-check":
        if KEYFILE.exists() or any("crypto_keyfile.bin" in value for value in output[1:]):
            raise ValueError(
                "Implicit crypto_keyfile.bin requires user-managed systemd keyfile configuration."
            )
        for hook in hooks:
            if hook == "encrypt":
                continue
            for base in (ETC, LIB):
                for kind in ("install", "hooks"):
                    path = base / "initcpio" / kind / hook
                    if path.exists() and re.search(
                        r"crypto_keyfile[.]bin|cryptkey", path.read_text(), re.IGNORECASE
                    ):
                        raise ValueError(
                            f"Keyfile hook {path} requires user-managed systemd authentication."
                        )
    return hooks


def verify_unlock(cmdline: str, uuid: str, mapping: str) -> None:
    selected = named = restricted = disabled = quoted = False
    selectors: set[str] = set()
    for token in cmdline.split():
        escaped = any(char in token for char in ('"', "'", "\\"))
        if re.search(r"(?:cryptdevice|cryptkey|crypto|luks)[.=]", token) and (quoted or escaped):
            raise ValueError(
                "Quoted or escaped encryption arguments require manual reconciliation."
            )
        if token.count('"') % 2:
            quoted = not quoted
        token = token.removeprefix("rd.")
        if token in ("luks=0", "luks=no", "luks=false", "luks=off"):
            raise ValueError("Persistent configuration disables LUKS unlocking.")
        if token in (
            "luks.crypttab=0",
            "luks.crypttab=no",
            "luks.crypttab=false",
            "luks.crypttab=off",
        ):
            disabled = True
        if token.startswith("luks.options="):
            options = token.split("=", 1)[1]
            match = re.match(r"([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})=", options)
            if match:
                if match[1] != uuid:
                    continue
                options = options[len(match[0]) :]
            if any(
                re.fullmatch(r"noauto|swap|tmp(?:=.*)?|plain|tcrypt.*|bitlk|fvault2", option)
                for option in options.split(",")
            ):
                raise ValueError(
                    "Persistent root unlock options request a disabled or destructive non-LUKS mode."
                )
        if token.startswith(("luks.uuid=", "luks.name=")):
            if token in selectors:
                raise ValueError("Duplicate LUKS root selectors.")
            selectors.add(token)
            restricted = True
            if token in (f"luks.uuid={uuid}", f"luks.uuid=luks-{uuid}"):
                selected = True
            if token == f"luks.name={uuid}={mapping}":
                selected = named = True
            elif token.startswith(f"luks.name={uuid}=") or (
                token.startswith("luks.name=") and token.endswith(f"={mapping}")
            ):
                raise ValueError("Conflicting LUKS mapper selection.")
    if quoted or (restricted and not selected):
        raise ValueError("No unambiguous persistent root unlock selector.")
    if not disabled:
        path = ETC / "crypttab.initramfs"
        if not path.exists():
            path = ETC / "crypttab"
        if path.exists():
            entries: list[tuple[list[str], list[str]]] = []
            for line in path.read_text().splitlines():
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                fields = line.split()
                options = fields[3].split(",") if len(fields) > 3 else []
                if path.name != "crypttab.initramfs" and "x-initrd.attach" not in options:
                    continue
                if len(fields) > 1 and (
                    fields[0] == mapping
                    or fields[1] in (f"UUID={uuid}", f"/dev/disk/by-uuid/{uuid}")
                ):
                    entries.append((fields, options))
            if entries:
                fields, options = entries[0]
                if (
                    len(entries) != 1
                    or fields[0] != mapping
                    or fields[1] not in (f"UUID={uuid}", f"/dev/disk/by-uuid/{uuid}")
                    or any(
                        re.fullmatch(
                            r"noauto|swap|tmp(?:=.*)?|plain|tcrypt.*|bitlk|fvault2", option
                        )
                        for option in options
                    )
                ):
                    raise ValueError("Conflicting or destructive early crypttab root entry.")
                return
    if not named and not (selected and mapping == f"luks-{uuid}"):
        raise ValueError(
            f"No usable user-managed systemd early unlock for {mapping}; configure rd.luks.name={uuid}={mapping} or an included crypttab entry. TPM2 and credentials remain user-managed."
        )


def desired_hooks(previous: list[str], encrypted: bool) -> list[str]:
    hooks = [
        "base",
        "systemd",
        "autodetect",
        "microcode",
        "modconf",
        "kms",
        "keyboard",
        "sd-vconsole",
        "block",
    ]
    if "plymouth" in previous:
        hooks.append("plymouth")
    if encrypted:
        hooks.append("sd-encrypt")
    middle: list[str] = []
    tail: list[str] = []
    target = hooks
    for hook in previous:
        if hook in OBSOLETE:
            continue
        if hook == "filesystems":
            target = middle
            continue
        if hook == "fsck":
            target = tail
            continue
        if hook == "shutdown":
            hook = "sd-shutdown"
        if hook in hooks + middle + tail or (hook == "sd-encrypt" and not encrypted):
            continue
        target.append(hook)
    return [*hooks, "filesystems", *middle, "fsck", *tail]


def hook_exists(hook: str) -> bool:
    return any((base / "initcpio/install" / hook).is_file() for base in (ETC, LIB))


def configure_systemd_initramfs(parser: Path, state: Path) -> None:
    validate_mkinitcpio_options()
    device: BtrfsDevice = inspect_btrfs_device(Path("/"))
    mapping = backing = ""
    if device.luks_uuid:
        mapping = (SYS / "dev/block" / device.device_id / "dm/name").read_text().strip()
        parents = list((SYS / "dev/block" / device.device_id / "slaves").glob("*"))
        if len(parents) != 1:
            raise ValueError("Root mapping changed after inspection.")
        backing = (parents[0] / "dev").read_text().strip()
    args = (device.luks_uuid, mapping, device.uuid, backing)
    cmdline = parser_command(parser, "initramfs", device.luks_uuid)
    converting = re.search(r'(?:^|[\s"])cryptdevice=', cmdline) is not None
    if converting:
        cmdline = parser_command(parser, "convert-unlock", *args, "", "")
        _ = read_hooks("unlock-check")
    if device.luks_uuid:
        verify_unlock(cmdline, device.luks_uuid, mapping)
    previous = read_hooks("base")
    hooks = desired_hooks(previous, bool(device.luks_uuid))
    content = HEADER + "HOOKS=(" + " ".join(hooks) + ")"
    managed = ETC / "mkinitcpio.conf.d/00-chezmoi-systemd.conf"
    if (managed.exists() or managed.is_symlink()) and (
        managed.is_symlink()
        or not re.fullmatch(re.escape(HEADER) + r"HOOKS=\([\w -]+\)\n?", managed.read_text())
    ):
        raise ValueError(f"Preserved unrecognized or independent configuration: {managed}")
    if "__chezmoi_base_owner__" not in read_hooks(
        "candidate", content + "\nHOOKS+=(__chezmoi_base_owner__)"
    ):
        raise ValueError(
            "A later drop-in replaces the base HOOKS array; preserve append-only feature configuration."
        )
    effective = read_hooks("candidate", content)
    if (
        set(previous) & {"btrfs-overlayfs", "sd-btrfs-overlayfs"}
        and "sd-btrfs-overlayfs" not in effective
    ):
        raise ValueError(
            "Existing snapshot boot would lose its overlay; configure Snapper's independent selector."
        )
    ordered = effective.copy()
    if "sd-btrfs-overlayfs" not in hooks and "sd-btrfs-overlayfs" in ordered:
        ordered.remove("sd-btrfs-overlayfs")
    if ordered[: len(hooks)] != hooks:
        raise ValueError("Later configuration changes the managed systemd hooks.")
    if len(set(effective)) != len(effective):
        raise ValueError("Duplicate mkinitcpio hooks.")
    for hook in effective:
        if (
            hook in OBSOLETE
            or (hook == "sd-encrypt" and not device.luks_uuid)
            or not re.fullmatch(r"[a-zA-Z0-9_-]+", hook)
            or not hook_exists(hook)
        ):
            raise ValueError(f"Unavailable or incompatible mkinitcpio hook: {hook}")
    if not converting:
        write_dropin(managed.name, content, state)
        return
    managed.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="chezmoi-unlock-") as temporary:
        work = Path(temporary)
        configs: list[PolicyFile] = []
        stages: list[str] = []
        try:
            for name in ("kernel/cmdline", "limine-entry-tool.d/01-default.conf"):
                path = ETC / name
                stage = ""
                if path.is_file() and not path.is_symlink():
                    config = snapshot_config(path, work / f"{path.name}.before")
                    configs.append(config)
                    candidate = work / f"{path.name}.stage"
                    _ = candidate.write_bytes(config.backup.read_bytes())
                    stage = str(candidate)
                stages.append(stage)
            candidate = parser_command(parser, "convert-unlock", *args, *stages)
            if candidate != cmdline or read_hooks("candidate", content) != effective:
                raise ValueError("Boot configuration changed during unlock preflight.")
            verify_unlock(candidate, device.luks_uuid, mapping)
            config = snapshot_config(managed, work / "hooks.before")
            configs.append(config)
            request_rebuild(state)
            for config, stage in zip(
                configs[:-1], (value for value in stages if value), strict=True
            ):
                _ = publish_config(config, Path(stage).read_bytes())
            _ = publish_config(configs[-1], (content + "\n").encode(), mode=0o644)
            actual = parser_command(parser, "initramfs")
            verify_unlock(actual, device.luks_uuid, mapping)
            if actual != cmdline or read_hooks() != effective:
                raise ValueError(
                    "Published unlock or hook configuration differs from its verified candidate."
                )
        except BaseException:
            rollback_configs(configs)
            raise
