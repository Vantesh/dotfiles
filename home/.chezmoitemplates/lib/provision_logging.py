"""Private, bounded Loguru diagnostics shared by provisioning workflows."""

import errno
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from loguru import logger


def configure_logging() -> int:
    logger.remove()
    _ = logger.add(
        sys.stderr,
        # A callable format omits Loguru's automatic exception suffix on stderr.
        format=lambda _: (
            "<green>[{time:YYYY-MM-DD HH:mm:ss}]</green> <level>[{level}] {message}</level>\n"
        ),
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
        format="[{time:YYYY-MM-DD HH:mm:ss}] [{level}] [{file.name}:{line}] {message}",
        rotation=5 * 1024 * 1024,
        retention=5,
        delay=True,
        opener=private_log_file,
        diagnose=False,
        backtrace=False,
        catch=False,
    )


def run_logged(command: list[str], operation: str) -> None:
    """Log public, noninteractive command output without streaming it to the terminal.

    Never use for authentication, secrets, or commands that need native progress.
    Callers supply public context instead of logging arbitrary command arguments.
    """
    logger.debug("Running {}", operation)
    # Disk-backed capture bounds memory even for verbose upstream installers.
    with tempfile.TemporaryFile(mode="w+t") as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=False)
        _ = output.seek(0)
        tail = ""
        while chunk := output.read(16384):
            logger.debug("{} diagnostic:\n{}", operation, chunk.rstrip())
            tail = (tail + chunk)[-4096:]
    if result.returncode:
        reason = tail.strip().splitlines()[-1] if tail.strip() else "No command diagnostic available"
        raise subprocess.CalledProcessError(
            result.returncode, command, stderr=f"{operation}: {reason}"
        )
