#!/usr/bin/python3 -B
"""Private logging and personal authentication after the shell establishes prerequisites."""

import json
import os
import re
import subprocess
import sys
from contextlib import nullcontext
from pathlib import Path
from typing import cast

from loguru import logger


def configure_bitwarden() -> int:
    # Vault diagnostics and config can contain personal data; never log them.
    result = subprocess.run(
        ["rbw", "config", "show"], capture_output=True, text=True, errors="replace"
    )
    if result.returncode:
        profile = os.environ.get("RBW_PROFILE", "")
        directory = "rbw" + ("-" + profile if profile else "")
        config_file = (
            Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
            / directory
            / "config.json"
        )
        if config_file.exists() or config_file.is_symlink():
            logger.error(
                "Cannot read Bitwarden configuration (exit {}); inspect 'rbw config show'.",
                result.returncode,
            )
            return result.returncode
        config = {}
    else:
        try:
            parsed = cast("object", json.loads(result.stdout))
        except json.JSONDecodeError:
            logger.error("Bitwarden configuration is invalid JSON; inspect 'rbw config show'.")
            return 1
        if not isinstance(parsed, dict):
            logger.error("Bitwarden configuration must be an object; inspect 'rbw config show'.")
            return 1
        config = cast("dict[str, object]", parsed)

    email = config.get("email")
    if not isinstance(email, str) or not email:
        instruction = (
            "Configure Bitwarden with 'rbw config set email YOUR_EMAIL', then rerun setup."
        )
        if os.environ.get("NOCONFIRM") == "1" or any(
            os.environ.get(name)
            for name in (
                "CI",
                "GITHUB_ACTIONS",
                "GITLAB_CI",
                "CODESPACES",
            )
        ):
            logger.error(instruction)
            return 1
        try:
            with (
                nullcontext(sys.stdin) if sys.stdin.isatty() else Path("/dev/tty").open()
            ) as stream:
                while True:
                    print("Bitwarden email: ", end="", file=sys.stderr, flush=True)
                    response = stream.readline()
                    if not response:
                        logger.error("No email provided. {}", instruction)
                        return 1
                    email = response.strip()
                    if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
                        break
                    logger.warning("Enter a valid email address.")
        except OSError:
            logger.error("No interactive terminal. {}", instruction)
            return 1
        result = subprocess.run(
            ["rbw", "config", "set", "email", email],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode:
            logger.error("Cannot set Bitwarden email (exit {}).", result.returncode)
            return result.returncode
        logger.info("Configured Bitwarden email.")

    if config.get("lock_timeout") != 10800:
        result = subprocess.run(
            ["rbw", "config", "set", "lock_timeout", "10800"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode:
            logger.warning("Cannot set Bitwarden lock timeout (exit {}).", result.returncode)
        else:
            logger.info("Configured Bitwarden lock timeout.")

    # rbw uses pinentry for authentication. Keep stdin/environment available,
    # but discard command output rather than risking credentials in diagnostics.
    result = subprocess.run(["rbw", "login"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        logger.error(
            "Bitwarden login failed (exit {}); check pinentry and vault access, then retry.",
            result.returncode,
        )
    return result.returncode


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
    source = os.environ.get("CHEZMOI_SOURCE_DIR")
    if not source or not Path(source).is_absolute():
        print("ERROR: Chezmoi must supply an absolute CHEZMOI_SOURCE_DIR.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(Path(source) / ".chezmoitemplates"))
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        return configure_bitwarden()
    except OSError as error:
        filename = cast("object", error.filename)
        operation = "rbw" if filename == "rbw" else "Bootstrap"
        try:
            logger.error(
                "{} stopped (OS error {}); check Bitwarden configuration and setup-log permissions.",
                operation,
                error.errno,
            )
        except OSError:
            # The terminal sink reports first, even when the file is unwritable.
            if file_sink is not None:
                logger.remove(file_sink)
        return 1
    except KeyboardInterrupt:
        logger.warning("Bootstrap interrupted; rerun setup when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
