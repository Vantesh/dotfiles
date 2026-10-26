#!/usr/bin/python3 -B
"""Offer reboot guidance after verified boot setup, without unattended reboots."""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import cast

from loguru import logger


def main() -> int:
    personal = os.environ.get("DOTFILES_PERSONAL_ENABLED")
    if personal == "0":
        return 0
    if personal != "1":
        print(
            "ERROR: DOTFILES_PERSONAL_ENABLED must be '0' or '1'; run through Chezmoi.",
            file=sys.stderr,
        )
        return 1
    source_dir = Path(os.environ["CHEZMOI_SOURCE_DIR"])
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute source directory.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        if sys.argv[1:]:
            raise ValueError("Unsupported finalization arguments.")
        logger.info("Setup complete.")
        firmware = False
        try:
            result = subprocess.run(
                ["sbctl", "--json", "status"], check=True, capture_output=True, text=True
            )
            status = cast("dict[str, object]", json.loads(result.stdout))
            if type(status.get("secure_boot")) is not bool:
                raise ValueError("Unexpected Secure Boot status.")
            firmware = status["secure_boot"] is False
            if firmware:
                logger.info(
                    "Enable Secure Boot manually in UEFI firmware settings after successful setup."
                )
            else:
                logger.info("Secure Boot is enabled in firmware.")
        except OSError, ValueError, subprocess.CalledProcessError:
            # This is reboot guidance, not another provisioning or signing pass.
            logger.warning(
                "Cannot inspect firmware Secure Boot status; run sudo sbctl status before changing firmware settings."
            )
        hint = (
            "Run systemctl reboot --firmware-setup later to enable Secure Boot."
            if firmware
            else "Reboot manually later to apply all changes."
        )
        if os.environ.get("NOCONFIRM") == "1" or os.environ.get("CI"):
            logger.info(hint)
            return 0
        try:
            with Path("/dev/tty").open() as terminal, Path("/dev/tty").open("w") as prompt:
                question = (
                    "Reboot into UEFI firmware settings to enable Secure Boot?"
                    if firmware
                    else "Reboot now?"
                )
                _ = prompt.write(question + " [y/N] ")
                prompt.flush()
                if terminal.readline().strip().lower() not in ("y", "yes"):
                    logger.info(hint)
                    return 0
        except OSError:
            logger.info(hint)
            return 0
        _ = subprocess.run(
            ["systemctl", "reboot", *(["--firmware-setup"] if firmware else [])], check=True
        )
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            logger.opt(exception=True).error("Finalization failed (exit {}): {}", status, error)
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.info("Reboot declined; reboot manually when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
