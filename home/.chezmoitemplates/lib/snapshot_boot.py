"""Existing Limine snapshot settings and mkinitcpio overlay selection."""

import tempfile
from pathlib import Path

from .hibernation_policy import request_rebuild
from .initramfs import hook_exists, read_hooks
from .limine_config import ETC, configure_limine_settings, validate_mkinitcpio_options, write_dropin
from .policy_files import publish_config, snapshot_config

OVERLAY_CONFIG = """if [[ -n "${HOOKS:-}" && "${HOOKS@a}" != *a* ]]; then
  read -r -a HOOKS <<< "$HOOKS"
fi

_snapper_overlay=btrfs-overlayfs
if [[ " ${HOOKS[*]:-} " = *" systemd "* ]]; then
  _snapper_overlay=sd-btrfs-overlayfs
fi
if [[ " ${HOOKS[*]:-} " != *" $_snapper_overlay "* ]]; then
  if [[ "${HOOKS[-1]:-}" = strip ]]; then
    HOOKS[-1]="$_snapper_overlay"
    HOOKS+=(strip)
  else
    HOOKS+=("$_snapper_overlay")
  fi
fi
unset _snapper_overlay"""


def prepare_snapshot_boot(state: Path) -> None:
    validate_mkinitcpio_options()
    path = ETC / "default/limine"
    if not path.exists():
        # These are the same installed package templates used by the shell hook.
        content = (
            (ETC / "limine-entry-tool.conf").read_bytes()
            + b"\n\n"
            + (ETC / "limine-snapper-sync.conf").read_bytes()
        )
        with tempfile.TemporaryDirectory(prefix="chezmoi-snapper-boot-") as temporary:
            config = snapshot_config(path, Path(temporary) / "before")
            request_rebuild(state)
            _ = publish_config(config, content)
    settings = {
        "MAX_SNAPSHOT_ENTRIES": "10",
        "SNAPSHOT_FORMAT_CHOICE": "8",
        "TERMINAL": "xdg-terminal-exec",
        "TERMINAL_ARG": "--title=FloatingTerm",
        "QUIET_MODE": "yes",
        "ENABLE_LIMINE_FALLBACK": "no",
    }
    if (ETC / "kernel/cmdline").is_file():
        settings["ENABLE_UKI"] = "yes"
    configure_limine_settings(settings, state)


def configure_snapshot_overlay(state: Path) -> None:
    overlay = "sd-btrfs-overlayfs" if "systemd" in read_hooks() else "btrfs-overlayfs"
    if not hook_exists(overlay):
        raise ValueError(f"Required mkinitcpio snapshot hook is unavailable: {overlay}")
    write_dropin("snapper.conf", OVERLAY_CONFIG, state)
