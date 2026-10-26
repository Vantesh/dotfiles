#!/usr/bin/python3 -B
"""Select Ly on tty1 for the next boot without activating or stopping sessions."""

import os
import re
import signal
import subprocess
import sys
import tempfile
import traceback
from pathlib import Path
from typing import cast

from loguru import logger

LY = "ly@tty1.service"
GETTY = "getty@tty1.service"
LY_BINARY = Path("/usr/bin/ly-dm")
LY_CONFIG = Path("/etc/ly/config.ini")
SYSTEMD_DIRS = (Path("/etc/systemd/system"), Path("/run/systemd/system"))
COMPETITORS = (
    "sddm.service",
    "greetd.service",
    "gdm.service",
    "gdm3.service",
    "lightdm.service",
    "lxdm.service",
    "emptty.service",
)
ENABLED = ("enabled", "enabled-runtime")


def unit_properties(unit: str) -> dict[str, str]:
    result = subprocess.run(
        [
            "systemctl",
            "show",
            "--property=Id,LoadState,UnitFileState,FragmentPath,TTYPath,Conflicts",
            unit,
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    properties = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if properties.get("LoadState") != "not-found":
        result.check_returncode()
    if (
        not properties.get("Id")
        or "LoadState" not in properties
        or "UnitFileState" not in properties
    ):
        raise ValueError(f"Cannot inspect systemd unit {unit}.")
    return properties


def disable_login_unit(unit: str, state: str, attempted: list[tuple[str, str]]) -> None:
    # Persistent enablement hides an additional runtime scope. Disabling the
    # first exposes the second; remember each confirmed scope before changing it.
    for scope in ENABLED:
        if state != scope:
            continue
        attempted.append((unit, scope))
        _ = subprocess.run(
            ["systemctl", *(["--runtime"] if scope == "enabled-runtime" else []), "disable", unit],
            check=True,
        )
        state = unit_properties(unit)["UnitFileState"]
        if state == scope:
            raise ValueError(f"{unit} remains {state} after disabling it.")
    if state in ENABLED:
        raise ValueError(f"{unit} became enabled unexpectedly during disablement.")


def display_manager_owner(managers: set[str]) -> str | None:
    visible = unit_properties("display-manager.service")
    owners: set[str] = set()
    for directory in SYSTEMD_DIRS:
        alias = directory / "display-manager.service"
        if not alias.is_symlink():
            if alias.exists():
                raise ValueError(f"Refusing non-symlink display-manager alias: {alias}")
            continue
        name = alias.readlink().name
        if name not in managers:
            raise ValueError(
                f"Unknown display-manager alias target {alias}: {name}; review it manually."
            )
        properties = unit_properties(name)
        if properties["LoadState"] != "loaded" or properties["Id"] not in managers:
            raise ValueError(
                f"Display-manager alias points to an unavailable or unexpected unit: {alias}"
            )
        if alias.resolve(strict=True) != Path(properties["FragmentPath"]).resolve(strict=True):
            raise ValueError(
                f"Display-manager alias does not point to the inspected unit file: {alias}"
            )
        owners.add(properties["Id"])
    if not owners and visible["LoadState"] == "not-found":
        return None
    if len(owners) != 1 or visible["LoadState"] != "loaded" or visible["Id"] not in owners:
        raise ValueError(
            "Unexpected or ambiguous display-manager.service ownership; inspect its /etc, /run and vendor origins before switching."
        )
    return next(iter(owners))


def configure_login_manager() -> None:
    from lib.policy_files import publish_config, rollback_configs, snapshot_config

    if os.geteuid() != 0:
        raise PermissionError("Login-manager configuration requires root privileges.")
    _ = subprocess.run(["pacman", "-Q", "--", "ly"], check=True, stdout=subprocess.DEVNULL)
    if not os.access(LY_BINARY, os.X_OK) or not LY_CONFIG.is_file():
        raise FileNotFoundError(
            "Ly executable/configuration is missing; complete package installation."
        )
    ly = unit_properties(LY)
    if (
        ly["LoadState"] != "loaded"
        or ly["Id"] != LY
        or ly.get("TTYPath") != "/dev/tty1"
        or GETTY not in ly.get("Conflicts", "").split()
        or ly["UnitFileState"] not in ("enabled", "disabled")
    ):
        raise ValueError(
            "Ly must provide an unmasked tty1 unit with its native getty conflict; inspect ly@tty1.service."
        )
    # Discover actual enabled Ly instances rather than retaining a tty2 policy.
    listed = subprocess.run(
        [
            "systemctl",
            "list-unit-files",
            "--no-legend",
            "--no-pager",
            "--state=enabled,enabled-runtime",
            "ly@*.service",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    other_ly: list[str] = []
    for line in listed.stdout.splitlines():
        name = line.split()[0]
        if re.fullmatch(r"ly@tty[0-9]+\.service", name) is None:
            raise ValueError(f"Unsupported enabled Ly instance: {name}")
        if name != LY:
            other_ly.append(name)
    states: dict[str, str] = {}
    managers = {LY, *COMPETITORS, *other_ly}
    for name in (*COMPETITORS, *other_ly, GETTY):
        properties = unit_properties(name)
        if properties["LoadState"] == "not-found":
            continue
        canonical = properties["Id"]
        if canonical not in managers | {GETTY}:
            raise ValueError(f"Unexpected canonical identity for {name}: {canonical}")
        state = properties["UnitFileState"]
        if state not in (
            *ENABLED,
            "disabled",
            "static",
            "indirect",
            "alias",
            "masked",
            "masked-runtime",
        ):
            raise ValueError(f"Unsupported enablement state for {canonical}: {state}")
        states[canonical] = state
    owner = display_manager_owner(managers)
    if owner and owner != LY and states.get(owner) not in ENABLED:
        raise ValueError(
            f"Shared alias selects {owner}, but its enablement is unexpected; inspect the alias origin."
        )

    with tempfile.TemporaryDirectory(prefix="chezmoi-ly-") as directory:
        config = snapshot_config(LY_CONFIG, Path(directory) / "config.ini")
        content = config.backup.read_text()
        for key, value in {
            "allow_empty_password": "false",
            "clear_password": "true",
            "bigclock": "en",
            "hide_key_hints": "true",
            "border_fg": "8",
            "path": "null",
            "hide_version_string": "true",
        }.items():
            content, found = re.subn(
                rf"(?m)^[ \t]*#?[ \t]*{key}[ \t]*=.*$", f"{key} = {value}", content
            )
            if not found:
                content += f"\n{key} = {value}\n"
        attempted: list[tuple[str, str]] = []
        enable_attempted = False
        try:
            changed = publish_config(config, content.encode())
            # Only installation state changes: never activate, stop or restart a unit.
            for name, state in states.items():
                if name == GETTY or state not in ENABLED:
                    continue
                disable_login_unit(name, state, attempted)
            if display_manager_owner(managers) not in (None, LY):
                raise ValueError(
                    "A recognized display-manager alias remains after disablement; inspect its exact origin before switching."
                )
            if states.get(GETTY) in ENABLED:
                disable_login_unit(GETTY, states[GETTY], attempted)
            if ly["UnitFileState"] != "enabled":
                enable_attempted = True
                _ = subprocess.run(["systemctl", "enable", LY], check=True)
            if unit_properties(LY)["UnitFileState"] != "enabled":
                raise ValueError(
                    "Ly did not become persistently enabled; do not reboot until enablement is repaired."
                )
            for name in states:
                if unit_properties(name)["UnitFileState"] in ENABLED:
                    raise ValueError(f"Conflicting unit remains enabled: {name}")
            if display_manager_owner(managers) not in (None, LY):
                raise ValueError("Display-manager alias changed unexpectedly during Ly enablement.")
        except BaseException:
            # Restore only the few enablement operations attempted here. Native
            # enable restores known aliases; never overwrite links with --force.
            blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
            restored = True
            try:
                # Restore runtime first: it would otherwise be hidden by a restored
                # persistent scope. Restore the original alias owner before peers.
                recovery = sorted(
                    attempted, key=lambda item: (item[0] != owner, item[1] == "enabled")
                )
                for name, state in recovery:
                    try:
                        if unit_properties(name)["UnitFileState"] != state:
                            _ = subprocess.run(
                                [
                                    "systemctl",
                                    *(["--runtime"] if state == "enabled-runtime" else []),
                                    "enable",
                                    name,
                                ],
                                check=True,
                            )
                        if unit_properties(name)["UnitFileState"] != state:
                            raise ValueError(f"Could not restore prior enablement of {name}.")
                    except (OSError, ValueError, subprocess.CalledProcessError) as error:
                        restored = False
                        print(
                            f"Login-manager recovery failed for {name}: {error}; inspect before rebooting.",
                            file=sys.stderr,
                        )
                # Keep a partially enabled Ly as a fallback if restoration failed.
                if enable_attempted and restored:
                    try:
                        _ = subprocess.run(["systemctl", "disable", LY], check=True)
                        if unit_properties(LY)["UnitFileState"] != "disabled":
                            raise ValueError("Partial Ly enablement remains after recovery.")
                    except (OSError, ValueError, subprocess.CalledProcessError) as error:
                        print(
                            f"Could not remove partial Ly enablement: {error}; inspect before rebooting.",
                            file=sys.stderr,
                        )
                rollback_configs([config])
            finally:
                _ = signal.pthread_sigmask(signal.SIG_SETMASK, blocked)
            raise
        if changed:
            print("Configured Ly appearance and password-clearing preferences.")
        if attempted or enable_attempted:
            print(
                "Ly is enabled on tty1 for the next boot; running sessions are unchanged. Reboot deliberately when ready."
            )


def terminate(_signum: int, _frame: object) -> None:
    raise SystemExit(143)


def main() -> int:
    privileged = sys.argv[1:2] == ["--apply-login"]
    if privileged and len(sys.argv) != 4:
        print("ERROR: Privileged Ly setup requires its source path and profile.", file=sys.stderr)
        return 1
    personal = sys.argv[3] if privileged else os.environ.get("DOTFILES_PERSONAL_ENABLED")
    if personal == "0":
        return 0
    if personal != "1":
        print(
            "ERROR: DOTFILES_PERSONAL_ENABLED must be '0' or '1'; run through Chezmoi.",
            file=sys.stderr,
        )
        return 1
    try:
        source_dir = Path(sys.argv[2]) if privileged else Path(os.environ["CHEZMOI_SOURCE_DIR"])
    except KeyError:
        print("ERROR: Chezmoi must supply CHEZMOI_SOURCE_DIR.", file=sys.stderr)
        return 1
    if not source_dir.is_absolute():
        print("ERROR: Chezmoi must supply an absolute source directory.", file=sys.stderr)
        return 1
    sys.path.insert(0, str(source_dir / ".chezmoitemplates"))
    _ = signal.signal(signal.SIGTERM, terminate)
    if privileged:
        try:
            configure_login_manager()
            return 0
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            traceback.print_exc()
            return error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        except KeyboardInterrupt:
            return 130
    from lib.provision_logging import configure_logging

    file_sink = None
    try:
        file_sink = configure_logging()
        if sys.argv[1:]:
            raise ValueError("Unsupported login-manager arguments.")
        if os.geteuid() == 0:
            raise ValueError(
                "Run Ly setup as the regular account; sudo applies system configuration."
            )
        _ = subprocess.run(["sudo", "-v"], check=True)
        result = subprocess.run(
            [
                "sudo",
                "-n",
                sys.executable,
                "-B",
                str(Path(__file__).resolve()),
                "--apply-login",
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
        diagnostic = (
            cast("str | None", error.stderr)
            if isinstance(error, subprocess.CalledProcessError)
            else None
        )
        try:
            reason = (
                diagnostic.strip().splitlines()[-1]
                if diagnostic and diagnostic.strip()
                else str(error)
            )
            logger.opt(exception=True).error(
                "Ly setup failed (exit {}): {}; inspect enablement before rebooting.",
                status,
                reason,
            )
            if diagnostic:
                logger.debug("Ly diagnostic:\n{}", diagnostic.rstrip())
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Ly setup interrupted; inspect enablement and reapply before rebooting.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
