"""Prerequisites for chezmoi rendering; desktop packages remain owned by Mise."""

import errno
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from contextlib import nullcontext
from pathlib import Path
from typing import cast

from loguru import logger


def install_prerequisites() -> int:
    packages = ["git", "base-devel"]
    if not shutil.which("mise"):
        packages.append("mise")
    if os.environ.get("PERSONAL") == "1":
        packages.extend(("rbw", "pinentry"))
    missing = [
        package
        for package in packages
        if subprocess.run(
            ["pacman", "-Q", package],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
    ]
    if not missing:
        return 0

    logger.info("Installing prerequisites: {}", ", ".join(missing))
    result = subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "--", *missing])
    if result.returncode:
        logger.error(
            "Prerequisite installation failed (exit {}); resolve pacman's error and rerun setup.",
            result.returncode,
        )
    return result.returncode


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


def configure_logging() -> int:
    logger.remove()
    _ = logger.add(
        sys.stderr,
        format="<green>{time:HH:mm:ss}</green> | <level>{level: <7}</level> | <level>{message}</level>",
        colorize=sys.stderr.isatty()
        and "NO_COLOR" not in os.environ
        and os.environ.get("TERM") != "dumb",
        level="INFO",
        diagnose=False,
        backtrace=False,
        catch=False,
    )

    log_dir = (
        Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "chezmoi/logs"
    )
    log_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory = log_dir.lstat()
    if not stat.S_ISDIR(directory.st_mode) or directory.st_uid != os.getuid():
        raise PermissionError(
            errno.EACCES, "Setup logs require a user-owned directory, not a symlink"
        )
    if stat.S_IMODE(directory.st_mode) != 0o700:
        log_dir.chmod(0o700)

    # Loguru uses this native open() hook for the current file and every rotation.
    def private_log_file(path: str, flags: int) -> int:
        # A FIFO must not block before the regular-file check below can reject it.
        descriptor = os.open(path, flags | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
        try:
            info = os.fstat(descriptor)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                raise PermissionError(errno.EACCES, "Setup logs require a user-owned regular file")
            if stat.S_IMODE(info.st_mode) != 0o600:
                os.fchmod(descriptor, 0o600)
        except OSError:
            os.close(descriptor)
            raise
        return descriptor

    return logger.add(
        log_dir / "setup.log",
        level="DEBUG",
        colorize=False,
        format="{time:YYYY-MM-DD HH:mm:ss.SSS ZZ} | {level: <7} | {function}:{line} | {message}",
        rotation=5 * 1024 * 1024,
        retention=5,
        delay=True,
        opener=private_log_file,
        diagnose=False,
        backtrace=False,
        catch=False,
    )


def main() -> int:
    file_sink = None
    try:
        file_sink = configure_logging()
        status = install_prerequisites()
        if status or os.environ.get("PERSONAL") != "1":
            return status
        return configure_bitwarden()
    except OSError as error:
        filename = cast("object", error.filename)
        operation = filename if filename in ("pacman", "sudo", "rbw") else "Bootstrap"
        try:
            logger.error(
                "{} stopped (OS error {}); check prerequisite commands, configuration and setup-log permissions.",
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
