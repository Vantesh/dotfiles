#!/usr/bin/python3 -B
"""Use the managed Atuin config, then retain personal login and initial sync."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

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
        config_dir = Path.home() / ".config/atuin"
        # dot_config has a fixed Chezmoi target, independent of XDG_CONFIG_HOME.
        # This file must exist before Atuin resolves ATUIN_DATA_DIR on first launch.
        if not (config_dir / "config.toml").is_file():
            logger.error(
                "Missing Chezmoi-managed Atuin config: {}; apply managed files first.",
                config_dir / "config.toml",
            )
            return 1
        env = {
            **os.environ,
            "ATUIN_HOME": str(config_dir),
            "ATUIN_CONFIG_DIR": str(config_dir),
            "ATUIN_DATA_DIR": str(
                Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "atuin"
            ),
            "ATUIN_LOGS__DIR": str(
                Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "atuin"
            ),
        }
        if runtime_dir := os.environ.get("XDG_RUNTIME_DIR"):
            env["ATUIN_DAEMON__SOCKET_PATH"] = str(Path(runtime_dir) / "atuin.sock")
            env["ATUIN_DAEMON__PIDFILE_PATH"] = str(Path(runtime_dir) / "atuin.pid")
        if shutil.which("atuin") is None:
            logger.error("atuin not found; complete package installation.")
            return 127
        status = subprocess.run(
            ["atuin", "status"],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if status.returncode == 0:
            return 0
        credentials: list[str] = []
        for field in ("username", "password", "atuin_key"):
            result = subprocess.run(
                ["rbw", "get", "--field", field, "Atuin"],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if result.returncode:
                logger.error(
                    "Cannot retrieve Atuin credentials (exit {}); inspect the Atuin vault entry.",
                    result.returncode,
                )
                return result.returncode
            try:
                # rbw adds one newline; preserve all whitespace within the field.
                credentials.append(result.stdout.removesuffix(b"\n").decode("utf-8"))
            except UnicodeDecodeError:
                logger.error(
                    "Atuin vault fields must contain valid UTF-8; inspect the Atuin entry."
                )
                return 1
        username, password, key = credentials
        # Never raise a CalledProcessError or record output for credential-bearing
        # commands: both arguments and diagnostics may contain secrets.
        login = subprocess.run(
            ["atuin", "login", "--username", username, "--password", password, "--key", key],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if login.returncode:
            logger.error(
                "Atuin login failed (exit {}); check the Atuin vault entry and server access.",
                login.returncode,
            )
            return login.returncode
        sync = subprocess.run(["atuin", "sync"], env=env, check=False)
        if sync.returncode:
            logger.error(
                "Atuin sync failed (exit {}); inspect Atuin connectivity and reapply.",
                sync.returncode,
            )
            return sync.returncode
        logger.info("Logged in to Atuin and synced history.")
        return 0
    except OSError as error:
        try:
            logger.error(
                "Atuin setup stopped (OS error {}); check required commands and setup-log permissions.",
                error.errno,
            )
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return 1
    except KeyboardInterrupt:
        logger.warning("Atuin setup interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
