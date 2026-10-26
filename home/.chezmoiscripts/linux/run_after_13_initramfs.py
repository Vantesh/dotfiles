#!/usr/bin/python3 -B
"""Reconcile pending boot changes after all configuration hooks, then verify before clearing."""

import os
import signal
import subprocess
import sys
import traceback
from pathlib import Path
from typing import cast

from loguru import logger


def terminate(_signum: int, _frame: object) -> None:
    raise SystemExit(143)


def main() -> int:
    privileged = sys.argv[1:2] == ["--rebuild"]
    if privileged and len(sys.argv) != 5:
        print(
            "ERROR: Boot setup requires its state directory, source directory and profile.",
            file=sys.stderr,
        )
        return 1
    personal = sys.argv[4] if privileged else os.environ.get("DOTFILES_PERSONAL_ENABLED")
    if personal == "0":
        return 0
    if personal != "1":
        print(
            "ERROR: DOTFILES_PERSONAL_ENABLED must be '0' or '1'; run through Chezmoi.",
            file=sys.stderr,
        )
        return 1
    source_dir = Path(sys.argv[3]) if privileged else Path(os.environ["CHEZMOI_SOURCE_DIR"])
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute source directory.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    _ = signal.signal(signal.SIGTERM, terminate)
    from lib.boot_rebuild import rebuild_boot

    if privileged:
        try:
            state = Path(sys.argv[2])
            if os.geteuid() != 0 or not state.is_absolute():
                raise ValueError(
                    "Privileged boot setup requires root and an absolute state directory."
                )
            rebuild_boot(state)
            return 0
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            traceback.print_exc()
            if isinstance(error, subprocess.CalledProcessError):
                diagnostic = cast("str | None", error.stderr)
                if diagnostic:
                    print(diagnostic, file=sys.stderr, end="")
                return error.returncode
            if isinstance(error, FileNotFoundError):
                filename = cast("str | None", error.filename)
                if filename and not Path(filename).is_absolute():
                    return 127
            return 1
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        if sys.argv[1:] or os.geteuid() == 0:
            raise ValueError("Run boot provisioning as the regular account without arguments.")
        state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "chezmoi"
        pending = state / "initramfs.pending"
        if not pending.exists() and not pending.is_symlink():
            return 0
        _ = subprocess.run(["sudo", "-v"], check=True)
        result = subprocess.run(
            [
                "sudo",
                "-n",
                sys.executable,
                "-B",
                str(Path(__file__).resolve()),
                "--rebuild",
                str(state),
                str(source_dir),
                personal,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for message in result.stdout.splitlines():
            logger.info(message)
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            if isinstance(error, subprocess.CalledProcessError):
                diagnostic = cast("str | None", error.stderr)
                reason = (
                    diagnostic.strip().splitlines()[-1]
                    if diagnostic and diagnostic.strip()
                    else str(error)
                )
                logger.error("Boot setup failed (exit {}): {}", status, reason)
                if diagnostic:
                    logger.debug("System diagnostic:\n{}", diagnostic.rstrip())
            else:
                logger.opt(exception=True).error("Boot setup failed (exit {}): {}", status, error)
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Boot setup interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
