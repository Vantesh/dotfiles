#!/usr/bin/python3 -B
"""Offer native enrollment only for the verified personal Goodix 5395 setup."""

import os
import pwd
import re
import subprocess
import sys
from pathlib import Path
from typing import cast

from loguru import logger

USB_DEVICES = Path("/sys/bus/usb/devices")


def has_enrolled_fingers(device: str) -> bool:
    result = subprocess.run(
        [
            "gdbus",
            "call",
            "--system",
            "--dest",
            "net.reactivated.Fprint",
            "--object-path",
            device,
            "--method",
            "net.reactivated.Fprint.Device.ListEnrolledFingers",
            "",
        ],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        if "net.reactivated.Fprint.Error.NoEnrolledPrints:" in result.stderr:
            return False
        result.check_returncode()
    fingers = result.stdout.strip()
    if fingers in ("(@as [],)", "([],)"):
        return False
    if not re.fullmatch(r"\(\['[a-z-]+'(?:, '[a-z-]+')*\],\)", fingers):
        raise ValueError("Cannot interpret fprintd's enrolled-finger response.")
    return True


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
        if os.environ.get("NOCONFIRM") == "1" or os.environ.get("CI"):
            logger.info("Fingerprint enrollment skipped unattended; enroll manually when ready.")
            return 0
        for device in USB_DEVICES.iterdir():
            vendor, product = device / "idVendor", device / "idProduct"
            if (
                vendor.is_file()
                and product.is_file()
                and vendor.read_text().strip().lower() == "27c6"
                and product.read_text().strip().lower() == "5395"
            ):
                break
        else:
            return 0
        driver = "libfprint-goodix53x5-533c-git"
        package = subprocess.run(
            ["pacman", "-Q", "--", driver],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            env={**os.environ, "LC_ALL": "C"},
            text=True,
            check=False,
        )
        if (
            package.returncode == 1
            and package.stderr.strip() == f"error: package '{driver}' was not found"
        ):
            logger.warning(
                "Goodix 27c6:5395 has no declared compatible driver; skipping enrollment."
            )
            return 0
        package.check_returncode()
        if os.getuid() == 0:
            raise ValueError(
                "Run fingerprint setup as the regular account; sudo handles enrollment."
            )
        target_user = pwd.getpwuid(os.getuid()).pw_name
        env = {**os.environ, "LC_ALL": "C"}
        result = subprocess.run(
            [
                "gdbus",
                "call",
                "--system",
                "--dest",
                "net.reactivated.Fprint",
                "--object-path",
                "/net/reactivated/Fprint/Manager",
                "--method",
                "net.reactivated.Fprint.Manager.GetDefaultDevice",
            ],
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        match = re.fullmatch(
            r"\(objectpath '(/net/reactivated/Fprint/Device/[0-9]+)',\)", result.stdout.strip()
        )
        if match is None:
            raise ValueError("Cannot identify fprintd's default device.")
        device = match[1]
        result = subprocess.run(
            [
                "gdbus",
                "call",
                "--system",
                "--dest",
                "net.reactivated.Fprint",
                "--object-path",
                device,
                "--method",
                "org.freedesktop.DBus.Properties.Get",
                "net.reactivated.Fprint.Device",
                "name",
            ],
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        # The declared driver's full_name and USB table were verified together.
        if result.stdout.strip() != "(<'Goodix HTK32 Fingerprint Sensor'>,)":
            logger.warning(
                "fprintd's default reader is not the supported Goodix driver; skipping enrollment."
            )
            return 0
        if has_enrolled_fingers(device):
            return 0
        try:
            with Path("/dev/tty").open() as terminal, Path("/dev/tty").open("w") as prompt:
                _ = prompt.write("Enroll a fingerprint now? Touch the reader when prompted. [y/N] ")
                prompt.flush()
                if terminal.readline().strip().lower() not in ("y", "yes"):
                    logger.info("Fingerprint enrollment declined; existing prints are unchanged.")
                    return 0
                # Explicit account argument keeps native sudo enrollment usable on a
                # console without requiring a graphical authorization agent.
                _ = subprocess.run(
                    ["sudo", "fprintd-enroll", "-f", "right-index-finger", target_user],
                    env=env,
                    stdin=terminal,
                    stdout=prompt,
                    stderr=prompt,
                    check=True,
                )
        except OSError as error:
            if cast("str | None", error.filename) != "/dev/tty":
                raise
            logger.info("Fingerprint enrollment needs a terminal; run fprintd-enroll later.")
            return 0
        if not has_enrolled_fingers(device):
            raise ValueError(
                "Native enrollment returned success but fprintd has no enrolled prints."
            )
        logger.info("Fingerprint enrollment completed.")
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        status = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        # Only read-only package/D-Bus queries capture stderr. Native enrollment
        # stays on the terminal, so biometric output cannot enter these diagnostics.
        diagnostic = (
            cast("str | None", error.stderr)
            if isinstance(error, subprocess.CalledProcessError)
            else None
        )
        try:
            logger.opt(exception=True).error(
                "Fingerprint setup failed (exit {}); check the Goodix driver and fprintd: {}",
                status,
                diagnostic.strip() if diagnostic and diagnostic.strip() else error,
            )
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return status
    except KeyboardInterrupt:
        logger.warning("Fingerprint enrollment interrupted; reapply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
