#!/usr/bin/python3 -B
"""Install upstream auto-cpufreq on personal laptops; upstream owns its daemon."""

import configparser
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import cast

from loguru import logger

AUTO_CPUFREQ_BIN = Path("/usr/local/bin/auto-cpufreq")


def install_auto_cpufreq() -> None:
    result = subprocess.run(
        [
            "curl",
            "-fsSL",
            "-m",
            "60",
            "https://api.github.com/repos/AdnanHodzic/auto-cpufreq/releases/latest",
        ],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    release = cast("dict[str, object]", json.loads(result.stdout))
    version = release["tag_name"]
    if not isinstance(version, str) or not version.strip():
        raise ValueError("GitHub returned an invalid auto-cpufreq release tag.")
    directory = Path(tempfile.mkdtemp(prefix="chezmoi-auto-cpufreq-"))
    try:
        checkout = directory / "auto-cpufreq"
        logger.info("Installing auto-cpufreq {} from upstream.", version)
        # Dunamai's strict versioning requires the full release history.
        _ = subprocess.run(
            [
                "git",
                "clone",
                "--single-branch",
                "--branch",
                version,
                "--",
                "https://github.com/AdnanHodzic/auto-cpufreq.git",
                str(checkout),
            ],
            check=True,
        )
        _ = subprocess.run(
            ["sudo", "bash", str(checkout / "auto-cpufreq-installer"), "--install"],
            check=True,
        )
    finally:
        failed = sys.exception() is not None
        try:
            # The root-run build can leave root-owned files in this private checkout.
            _ = subprocess.run(["sudo", "rm", "-rf", "--", str(directory)], check=True)
        except OSError, subprocess.CalledProcessError:
            if not failed:
                raise
            logger.warning("Could not remove auto-cpufreq source directory: {}", directory)


def bluetooth_boot_enabled() -> bool:
    bluetooth = configparser.ConfigParser(interpolation=None)
    with Path("/etc/bluetooth/main.conf").open() as config:
        bluetooth.read_file(config)
    return bluetooth.getboolean("Policy", "AutoEnable", fallback=False)


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
        chassis = subprocess.run(
            ["hostnamectl", "chassis"], check=True, stdout=subprocess.PIPE, text=True
        ).stdout.strip()
        if not chassis or len(chassis.splitlines()) != 1:
            raise ValueError("hostnamectl did not return a valid chassis type.")
        if chassis not in ("laptop", "notebook"):
            return 0
        if not os.access(AUTO_CPUFREQ_BIN, os.X_OK):
            install_auto_cpufreq()
            if not os.access(AUTO_CPUFREQ_BIN, os.X_OK):
                raise FileNotFoundError(f"Upstream installer did not provide {AUTO_CPUFREQ_BIN}.")
        # Upstream --install refuses an already-running daemon. Inspect only;
        # its official installer owns unit publication, conflicts and activation.
        daemon = subprocess.run(
            ["systemctl", "is-active", "--quiet", "auto-cpufreq.service"], check=False
        )
        if daemon.returncode != 0:
            if daemon.returncode not in (3, 4):
                daemon.check_returncode()
            _ = subprocess.run(["sudo", str(AUTO_CPUFREQ_BIN), "--install"], check=True)
            logger.info("Installed the auto-cpufreq daemon through upstream.")
        if not bluetooth_boot_enabled():
            _ = subprocess.run(["sudo", str(AUTO_CPUFREQ_BIN), "--bluetooth_boot_on"], check=True)
            # Upstream can report a write failure without a nonzero exit status.
            if not bluetooth_boot_enabled():
                raise ValueError("auto-cpufreq did not enable Bluetooth at boot.")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        configparser.Error,
        subprocess.CalledProcessError,
    ) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        try:
            logger.opt(exception=True).error(
                "Laptop power setup failed (exit {}): {}", status, error
            )
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Laptop power setup interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
