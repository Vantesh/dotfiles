#!/usr/bin/python3 -B
"""Register a standard WARP device for either profile without connecting."""

import os
import subprocess
import sys
from pathlib import Path

from loguru import logger


def main() -> int:
    try:
        source_dir = Path(os.environ["CHEZMOI_SOURCE_DIR"])
    except KeyError:
        print("ERROR: Chezmoi must supply CHEZMOI_SOURCE_DIR.", file=sys.stderr)
        return 1
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute source directory.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        env = {**os.environ, "LC_ALL": "C"}
        command = ["warp-cli", "--accept-tos", "registration", "show"]
        registration = subprocess.run(command, env=env, capture_output=True, text=True, check=False)
        if registration.returncode == 0:
            return 0
        # This native error is distinct from daemon/network/permission failures.
        # Registration output can identify an account; never persist its contents.
        if "Missing registration." not in registration.stdout + registration.stderr:
            registration.check_returncode()
        _ = subprocess.run(
            ["warp-cli", "--accept-tos", "registration", "new"],
            env=env,
            check=True,
            stdout=subprocess.DEVNULL,
        )
        _ = subprocess.run(command, env=env, capture_output=True, text=True, check=True)
        logger.info("Registered WARP; connect manually when wanted.")
        return 0
    except (OSError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            logger.opt(exception=True).error(
                "WARP registration failed (exit {}); check warp-svc and reapply: {}", status, error
            )
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("WARP registration interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
