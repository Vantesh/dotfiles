"""Keep NVIDIA sleep units in Mise and publish the existing PCI power policy."""

import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path
from typing import cast

from loguru import logger

from .hibernation_swap import ETC


def configure_nvidia_sleep(source_dir: Path, entrypoint: Path) -> None:
    info = subprocess.run(["lspci", "-nn"], check=True, capture_output=True, text=True).stdout
    if not any(
        "NVIDIA Corporation" in line
        and re.search(
            r"VGA compatible controller|3D controller|Display controller", line, re.IGNORECASE
        )
        for line in info.splitlines()
    ):
        return
    declarations = cast(
        "dict[str, object]",
        tomllib.loads((source_dir.parent / "mise/config.nvidia-sleep.toml").read_text()),
    )
    bootstrap = cast("dict[str, object]", declarations["bootstrap"])
    services = cast("dict[str, dict[str, str | bool]]", bootstrap["services"])
    selected: dict[str, dict[str, str | bool]] = {}
    for unit, declaration in services.items():
        load = subprocess.run(
            ["systemctl", "show", "--property=LoadState", "--value", "--", unit],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        if load in ("loaded", "masked"):
            selected[unit] = declaration
        elif load != "not-found":
            raise ValueError(f"Cannot inspect NVIDIA unit {unit}: LoadState={load}")
    if selected:
        with tempfile.TemporaryDirectory(prefix="chezmoi-nvidia-sleep-") as temporary:
            directory = Path(temporary)
            config = directory / "mise/config.nvidia-sleep.toml"
            config.parent.mkdir()
            content = f"min_version = {json.dumps(declarations['min_version'])}\n"
            for unit, declaration in selected.items():
                content += f"\n[bootstrap.services.{json.dumps(unit)}]\n"
                content += "".join(
                    f"{key} = {json.dumps(value)}\n" for key, value in declaration.items()
                )
            _ = config.write_text(content)
            env = os.environ.copy()
            for name in (
                "MISE_CONFIG_FILE",
                "MISE_GLOBAL_CONFIG_FILE",
                "MISE_SYSTEM_CONFIG_FILE",
                "MISE_OVERRIDE_CONFIG_FILENAMES",
                "MISE_ENV",
            ):
                _ = env.pop(name, None)
            env.update(
                MISE_CONFIG_DIR="/dev/null",
                MISE_SYSTEM_CONFIG_DIR="/dev/null",
                MISE_AUTO_ENV="false",
                MISE_CEILING_PATHS=str(directory.parent),
                MISE_TRUSTED_CONFIG_PATHS=str(config.parent),
            )
            _ = subprocess.run(
                ["mise", "--env", "nvidia-sleep", "bootstrap", "services", "apply", "--yes"],
                cwd=directory,
                env=env,
                check=True,
            )
    pci = subprocess.run(
        ["lspci", "-Dnnd", "10de:"], check=True, capture_output=True, text=True
    ).stdout.splitlines()
    address = pci[0].split()[0] if pci else ""
    if not address:
        listing = subprocess.run(["lspci", "-D"], check=True, capture_output=True, text=True).stdout
        address = next(
            (
                line.split()[0]
                for line in listing.splitlines()
                if re.search(r"NVIDIA.*(VGA|3D|Display)", line, re.IGNORECASE)
            ),
            "",
        )
    if address:
        if not re.fullmatch(r"[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]", address):
            raise ValueError("Invalid NVIDIA PCI address.")
        result = subprocess.run(
            [
                "sudo",
                "-n",
                sys.executable,
                "-B",
                str(entrypoint),
                "--nvidia-pm",
                address,
                str(source_dir),
                "1",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        for message in result.stdout.splitlines():
            logger.info(message)
    else:
        raise ValueError("Cannot identify the detected NVIDIA GPU's PCI address; inspect lspci.")


def configure_nvidia_power(address: str) -> None:
    from lib.policy_files import publish_config, snapshot_config

    if os.geteuid() != 0 or not re.fullmatch(
        r"[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]", address
    ):
        raise ValueError("Invalid privileged NVIDIA power invocation.")
    path = ETC / "tmpfiles.d/nvidia_pm.conf"
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        config = snapshot_config(path, Path(temporary) / "before")
        if publish_config(
            config,
            f"# NVIDIA power management\nw /sys/bus/pci/devices/{address}/power/control - - - - auto\n".encode(),
            mode=0o644,
        ):
            print(f"Configured NVIDIA power management for PCI {address}.")
