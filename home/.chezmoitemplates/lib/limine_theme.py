"""Preserve Limine entries and assets while applying the existing global appearance."""

import re
import tempfile
from pathlib import Path

from .hibernation_policy import request_rebuild
from .limine_config import boot_directory
from .policy_files import publish_config, replace_config, rollback_configs, snapshot_config

OPTIONS = {
    "timeout": "0.5",
    "terse": "yes",
    "quiet": "yes",
    "firmware_logo": "yes",
    "interface_help_hidden": "yes",
    "mouse": "no",
}


def appearance(content: str) -> str:
    result: list[str] = []
    emitted: set[str] = set()
    entry_seen = trim_padding = False
    pending_blanks = 0
    for line in content.splitlines():
        if trim_padding and not line.strip():
            continue
        trim_padding = False
        if not entry_seen and not line.strip():
            pending_blanks += 1
            continue
        if not entry_seen and line.startswith("/"):
            result.extend(f"{key}: {value}" for key, value in OPTIONS.items() if key not in emitted)
            emitted.update(OPTIONS)
            result.extend(("", "", ""))
            pending_blanks = 0
            entry_seen = trim_padding = True
            result.append(line)
            continue
        result.extend([""] * pending_blanks)
        pending_blanks = 0
        match = re.match(r"^\s*#?\s*([^:]+?)\s*:", line)
        key = match[1] if match else ""
        if key in OPTIONS:
            if not entry_seen and key not in emitted:
                result.append(f"{key}: {OPTIONS[key]}")
                emitted.add(key)
        else:
            result.append(line)
    if not entry_seen:
        raise ValueError(
            "Limine config has no boot entries; refusing to publish appearance settings."
        )
    transformed = "\n".join(result) + "\n"
    if sum(line.startswith("/") for line in content.splitlines()) != sum(
        line.startswith("/") for line in result
    ):
        raise ValueError("Generated Limine configuration changed the boot entry count.")
    return transformed


def configure_limine_theme(state: Path) -> None:
    path = boot_directory() / "limine.conf"
    with tempfile.TemporaryDirectory(prefix="chezmoi-limine-theme-") as temporary:
        work = Path(temporary)
        config = snapshot_config(path, work / "before")
        if config.original is None:
            raise ValueError(f"Limine config not found: {path}; complete bootloader setup.")
        content = appearance(config.backup.read_text()).encode()
        if content == config.backup.read_bytes():
            return
        backup = snapshot_config(path.with_suffix(".conf.bak"), work / "backup.before")
        _ = replace_config(backup.path, backup.original, config.backup.read_bytes(), config.backup)
        request_rebuild(state)
        try:
            _ = publish_config(config, content)
            if path.read_bytes() != content:
                raise ValueError(
                    "Limine appearance publication did not preserve the verified content."
                )
        except BaseException:
            rollback_configs([config])
            raise
