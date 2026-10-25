"""Prerequisites for chezmoi rendering; desktop packages remain owned by Mise."""

from contextlib import nullcontext
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from loguru import logger


def install_prerequisites():
    packages = ["git", "base-devel"]
    if not shutil.which("mise"):
        packages.append("mise")
    if os.environ.get("PERSONAL") == "1":
        packages.extend(("rbw", "pinentry"))
    missing = [package for package in packages if subprocess.run(
        ["pacman", "-Q", package], stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode]
    if not missing:
        return 0

    logger.info("Installing prerequisites: {}", ", ".join(missing))
    result = subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "--", *missing])
    if result.returncode:
        logger.error("Prerequisite installation failed (exit {}); resolve pacman's error and rerun setup.",
                     result.returncode)
    return result.returncode


def configure_bitwarden():
    # Vault diagnostics and config can contain personal data; never log them.
    result = subprocess.run(["rbw", "config", "show"], capture_output=True, text=True, errors="replace")
    if result.returncode:
        profile = os.environ.get("RBW_PROFILE", "")
        directory = "rbw" + ("-" + profile if profile else "")
        config_file = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / directory / "config.json"
        if config_file.exists() or config_file.is_symlink():
            logger.error("Cannot read Bitwarden configuration (exit {}); inspect 'rbw config show'.",
                         result.returncode)
            return result.returncode
        config = {}
    else:
        try:
            config = json.loads(result.stdout)
        except json.JSONDecodeError:
            logger.error("Bitwarden configuration is invalid JSON; inspect 'rbw config show'.")
            return 1
        if not isinstance(config, dict):
            logger.error("Bitwarden configuration must be an object; inspect 'rbw config show'.")
            return 1

    email = config.get("email")
    if not isinstance(email, str) or not email:
        instruction = "Configure Bitwarden with 'rbw config set email YOUR_EMAIL', then rerun setup."
        if os.environ.get("NOCONFIRM") == "1" or any(os.environ.get(name) for name in (
            "CI", "GITHUB_ACTIONS", "GITLAB_CI", "CODESPACES",
        )):
            logger.error(instruction)
            return 1
        try:
            terminal = nullcontext(sys.stdin) if sys.stdin.isatty() else open("/dev/tty")
        except OSError:
            logger.error("No interactive terminal. {}", instruction)
            return 1
        with terminal as stream:
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
        result = subprocess.run(["rbw", "config", "set", "email", email], capture_output=True)
        if result.returncode:
            logger.error("Cannot set Bitwarden email (exit {}).", result.returncode)
            return result.returncode
        logger.info("Configured Bitwarden email.")

    if config.get("lock_timeout") != 10800:
        result = subprocess.run(["rbw", "config", "set", "lock_timeout", "10800"], capture_output=True)
        if result.returncode:
            logger.warning("Cannot set Bitwarden lock timeout (exit {}).", result.returncode)
        else:
            logger.info("Configured Bitwarden lock timeout.")

    # rbw uses pinentry for authentication. Keep stdin/environment available,
    # but discard command output rather than risking credentials in diagnostics.
    result = subprocess.run(["rbw", "login"], capture_output=True)
    if result.returncode:
        logger.error("Bitwarden login failed (exit {}); check pinentry and vault access, then retry.",
                     result.returncode)
    return result.returncode


def main():
    logger.remove()
    logger.add(sys.stderr, format="<green>{time:HH:mm:ss}</green> | <level>{level: <7}</level> | <level>{message}</level>",
               colorize=sys.stderr.isatty() and "NO_COLOR" not in os.environ and os.environ.get("TERM") != "dumb",
               level="INFO", diagnose=False, backtrace=False)
    try:
        status = install_prerequisites()
        if status or os.environ.get("PERSONAL") != "1":
            return status
        return configure_bitwarden()
    except OSError as error:
        logger.error("Bootstrap could not complete (OS error {}); check prerequisite commands and configuration access.",
                     error.errno)
        return 1
    except KeyboardInterrupt:
        logger.warning("Bootstrap interrupted; rerun setup when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
