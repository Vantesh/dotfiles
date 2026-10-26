#!/usr/bin/python3 -B
"""Apply Nautilus preferences independently of desktop asset installation."""

import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path

from loguru import logger


def terminate(_signum: int, _frame: object) -> None:
    raise SystemExit(143)


def main() -> int:
    _ = signal.signal(signal.SIGTERM, terminate)
    source_dir = Path(os.environ["CHEZMOI_SOURCE_DIR"])
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute source directory.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        if shutil.which("gsettings") is None:
            logger.warning("gsettings unavailable; skipping Nautilus preferences.")
            return 0
        for schema, key, desired, value in (
            ("org.gnome.nautilus.icon-view", "default-zoom-level", "'small-plus'", "small-plus"),
            ("org.gnome.nautilus.preferences", "show-delete-permanently", "true", "true"),
        ):
            current = subprocess.run(
                ["gsettings", "get", schema, key], check=True, stdout=subprocess.PIPE, text=True
            ).stdout.strip()
            if current != desired:
                _ = subprocess.run(["gsettings", "set", schema, key, value], check=True)
                logger.info("Configured Nautilus {}.", key)
        return 0
    except (OSError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            logger.opt(exception=True).error(
                "Nautilus preferences failed (exit {}): {}", status, error
            )
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Nautilus preferences interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
