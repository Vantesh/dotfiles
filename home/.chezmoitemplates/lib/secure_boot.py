"""Personal sbctl provisioning; artifact signing stays in package hooks."""

import json
import re
import shutil
import subprocess
from pathlib import Path
from typing import cast

from .hibernation_policy import request_rebuild
from .limine_config import boot_directory, configure_limine_settings

VENDOR = Path("/sys/class/dmi/id/sys_vendor")


def secure_boot_status() -> dict[str, bool]:
    output = subprocess.run(
        ["sbctl", "--json", "status"], check=True, capture_output=True, text=True
    ).stdout
    value = cast("object", json.loads(output))
    if not isinstance(value, dict):
        raise ValueError("Unexpected sbctl status; refusing to modify Secure Boot keys.")
    fields = cast("dict[str, object]", value)
    if any(type(fields.get(key)) is not bool for key in ("installed", "setup_mode", "secure_boot")):
        raise ValueError("Unexpected sbctl status; refusing to modify Secure Boot keys.")
    return cast("dict[str, bool]", value)


def signing_certificate() -> str:
    output = subprocess.run(
        ["sbctl", "--json", "setup", "--print-config"], check=True, capture_output=True, text=True
    ).stdout
    config = cast("dict[str, dict[str, dict[str, object]]]", json.loads(output))
    path = config.get("keys", {}).get("db", {}).get("pubkey")
    if not isinstance(path, str) or not path or not Path(path).is_absolute():
        raise ValueError("sbctl configuration does not contain a usable db public certificate.")
    match = re.search(
        r"-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----",
        Path(path).read_text(),
        re.DOTALL,
    )
    certificate = re.sub(r"\s+", "", match[1]) if match else ""
    if not certificate:
        raise ValueError("sbctl db public certificate is empty or invalid.")
    return certificate


def check_signing_key(certificate: str | None = None) -> None:
    if certificate is None:
        certificate = signing_certificate()
    output = subprocess.run(
        ["sbctl", "--json", "list-enrolled-keys"], check=True, capture_output=True, text=True
    ).stdout
    enrolled = cast("dict[str, list[dict[str, str]]]", json.loads(output))
    if not certificate or not any(
        item.get("Raw") == certificate for item in enrolled.get("DB", [])
    ):
        raise ValueError(
            "Local db signing certificate is not enrolled; enroll it before rebuilding or signing Limine."
        )


def configure_secure_boot(state: Path) -> None:
    for command in ("sbctl", "mkinitcpio", "limine-enroll-config", "limine-update"):
        if shutil.which(command) is None:
            raise FileNotFoundError(f"Required Secure Boot command is missing: {command}")
    _ = boot_directory()
    status = secure_boot_status()
    if status["setup_mode"] and status["secure_boot"]:
        raise ValueError("Disable Secure Boot in UEFI settings before enrolling keys.")
    if not status["installed"] and not status["setup_mode"]:
        raise ValueError(
            "Enter UEFI Setup Mode with Secure Boot disabled, then reapply; existing keys were preserved."
        )
    if not status["installed"]:
        request_rebuild(state)
        _ = subprocess.run(["sbctl", "create-keys"], check=True, stderr=subprocess.PIPE, text=True)
    certificate = signing_certificate()
    if status["setup_mode"]:
        vendor = VENDOR.read_text().strip().lower() if VENDOR.is_file() else ""
        flags = ["--microsoft", "--ignore-immutable"]
        if "asus" not in vendor and "gigabyte" not in vendor:
            flags.append("--firmware-builtin")
        request_rebuild(state)
        _ = subprocess.run(
            ["sbctl", "enroll-keys", *flags], check=True, stderr=subprocess.PIPE, text=True
        )
        status = secure_boot_status()
        if status["setup_mode"]:
            raise ValueError(
                "Firmware remains in Setup Mode after enrollment; leave Secure Boot disabled until repaired."
            )
    check_signing_key(certificate)
    configure_limine_settings(
        {"ENABLE_VERIFICATION": "yes", "ENABLE_ENROLL_LIMINE_CONFIG": "yes"}, state
    )
