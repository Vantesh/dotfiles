"""Prepare package prerequisites, then let Mise apply the declared package groups."""

import argparse
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

from loguru import logger
from bootstrap import configure_logging


def prepare_xdg():
    home = Path.home()
    for name, default in {
        "XDG_CONFIG_HOME": home / ".config", "XDG_DATA_HOME": home / ".local/share",
        "XDG_CACHE_HOME": home / ".cache", "XDG_STATE_HOME": home / ".local/state",
        "XDG_BIN_HOME": home / ".local/bin", "XDG_RUNTIME_DIR": Path(f"/run/user/{os.getuid()}"),
    }.items():
        os.environ[name] = os.environ.get(name) or str(default)
    config, data, cache, state = (Path(os.environ[f"XDG_{name}_HOME"])
                                  for name in ("CONFIG", "DATA", "CACHE", "STATE"))
    # Only build-time paths are needed here; session application settings remain
    # in environment.d/00-xdg.conf.tmpl, rather than duplicating them all.
    for name, default in {
        "RUSTUP_HOME": data / "rustup", "CARGO_HOME": data / "cargo",
        "GOPATH": data / "go", "GOMODCACHE": cache / "go/mod", "GNUPGHOME": data / "gnupg",
    }.items():
        os.environ[name] = os.environ.get(name) or str(default)
    paths = os.environ.get("PATH", "").split(os.pathsep)
    if os.environ["XDG_BIN_HOME"] not in paths:
        paths.insert(0, os.environ["XDG_BIN_HOME"])
    for directory in (str(Path(os.environ["GOPATH"]) / "bin"), "/usr/bin/core_perl"):
        if directory not in paths:
            paths.append(directory)
    os.environ["PATH"] = os.pathsep.join(paths)

    gnupg = Path(os.environ["GNUPGHOME"])
    if gnupg.is_symlink():
        raise ValueError("Refusing a symlinked GnuPG home; check GNUPGHOME.")
    gnupg.mkdir(mode=0o700, parents=True, exist_ok=True)
    if stat.S_IMODE(gnupg.stat().st_mode) != 0o700:
        gnupg.chmod(0o700)
    # These parents are required by the declared Bash/Python history locations.
    for name in ("bash", "python"):
        (state / name).mkdir(parents=True, exist_ok=True)
    settings = config / "maven/settings.xml"
    if settings.exists() or settings.is_symlink():
        if not settings.is_file():
            raise ValueError("Maven settings must be a regular file; existing path was preserved.")
    else:
        settings.parent.mkdir(parents=True, exist_ok=True)
        stage = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=settings.parent, delete=False) as stage:
                stage.write('''<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>${env.XDG_DATA_HOME}/maven/repository</localRepository>
</settings>
''')
            os.link(stage.name, settings)
        finally:
            if stage is not None:
                Path(stage.name).unlink()


def setup_chaotic_aur():
    trust_missing = subprocess.run(["pacman", "-Q", "chaotic-keyring", "chaotic-mirrorlist"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0
    repositories = subprocess.run(["pacman-conf", "--repo-list"], check=True,
                                  capture_output=True, text=True).stdout.splitlines()
    enable = "chaotic-aur" not in repositories
    if trust_missing:
        key = "3056513887B78AEB"
        logger.info("Installing Chaotic-AUR signing trust and mirrorlist.")
        if subprocess.run(["sudo", "pacman-key", "--list-keys", key],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            subprocess.run(["sudo", "pacman-key", "--recv-key", key,
                            "--keyserver", "keyserver.ubuntu.com"], check=True)
        subprocess.run(["sudo", "pacman-key", "--lsign-key", key], check=True)
        subprocess.run(["sudo", "pacman", "-U", "--needed", "--noconfirm",
                        "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst",
                        "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"], check=True)
    if enable:
        logger.info("Enabling Chaotic-AUR.")
        subprocess.run(["sudo", "tee", "-a", "/etc/pacman.conf"], check=True, text=True,
                       input="\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n",
                       stdout=subprocess.DEVNULL)
    marker = Path(os.environ["XDG_STATE_HOME"]) / "chezmoi/chaotic-aur-updated"
    if enable or not marker.is_file():
        logger.info("Running the initial full system upgrade.")
        subprocess.run(["sudo", "pacman", "-Syu", "--noconfirm"], check=True)
        # Keep the existing marker only for this one-time prerequisite. Chezmoi
        # owns package execution state; failed upgrades must never record success.
        marker.touch()


def personal_packages(distro):
    groups = ["personal", "driver-utils"]
    pci = subprocess.run(["lspci", "-nn"], check=True, capture_output=True, text=True).stdout
    displays = [line for line in pci.splitlines() if re.search(r"\[03[0-9a-fA-F]{2}\]:", line)]
    if any("[8086:" in line.lower() for line in displays):
        groups.append("intel")
    nvidia = [line for line in displays if "[10de:" in line.lower()]
    families = set()
    for line in nvidia:
        architecture = re.search(r"\b(GM|GP|GV|TU|GA|AD|GB)[0-9]{3}[A-Z]*\b", line)
        families.add("legacy" if architecture and architecture[1] in ("GM", "GP", "GV")
                     else "current" if architecture else "unknown")
    family = next(iter(families)) if len(families) == 1 and "unknown" not in families else None
    if nvidia and not family:
        logger.warning("Unknown or mixed NVIDIA architectures; configure those drivers manually.")
    chassis = subprocess.run(["hostnamectl", "chassis"], check=True, capture_output=True, text=True).stdout.strip()
    if chassis in ("laptop", "notebook"):
        groups.append("laptop")
    for device in Path("/sys/bus/usb/devices").glob("*"):
        vendor, product = device / "idVendor", device / "idProduct"
        if vendor.is_file() and product.is_file() and vendor.read_text().strip() == "27c6" and product.read_text().strip() == "5395":
            groups.append("fingerprint-goodix")
            break
    if shutil.which("limine") and shutil.which("mkinitcpio"):
        groups.extend(("limine-mkinitcpio", "snapper"))
    else:
        logger.warning("Limine/mkinitcpio unavailable; skipping their personal package groups.")
    if not family:
        return groups, None, []

    installed = dict(line.split(maxsplit=1) for line in subprocess.run(
        ["pacman", "-Q"], check=True, capture_output=True, text=True).stdout.splitlines())
    stem = "nvidia-580xx" if family == "legacy" else "nvidia-open"
    utilities = "nvidia-580xx-utils" if family == "legacy" else "nvidia-utils"
    allowed = {stem, stem + "-lts", stem + "-dkms", utilities,
               "nvidia-580xx-settings" if family == "legacy" else "nvidia-settings",
               "opencl-nvidia-580xx" if family == "legacy" else "opencl-nvidia"}
    for name in installed:
        if re.fullmatch(r"(lib32-)?(nvidia(-[0-9]+xx)?(-utils|-settings|-dkms|-lts)?|nvidia-open(-dkms|-lts)?|opencl-nvidia(-[0-9]+xx)?)", name):
            if name.removeprefix("lib32-") not in allowed:
                raise ValueError(f"Installed {name} conflicts with the {family} NVIDIA family; configure the driver stack manually.")
    kernels = [name for name in installed if name in ("linux", "linux-zen", "linux-lts", "linux-hardened", "linux-cachyos")]
    headers = []
    for kernel in kernels:
        header = kernel + "-headers"
        if header not in installed:
            headers.extend((f"{kernel}={installed[kernel]}", f"{header}={installed[kernel]}"))
        elif installed[header] != installed[kernel]:
            raise ValueError(f"{kernel} and {header} versions differ; reconcile them with a supported full system upgrade.")
    if headers:
        # Mise skips version pins on pacman packages. Install only exact pairs;
        # never refresh metadata or upgrade a kernel to acquire its headers.
        logger.info("Installing matching kernel headers.")
        subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", "--", *headers], check=True)
        for target in headers:
            actual = subprocess.run(["pacman", "-Q", "--", target.split("=", 1)[0]],
                                    check=True, capture_output=True, text=True).stdout.strip()
            if actual != target.replace("=", " ", 1):
                raise ValueError("Kernel/header installation did not produce the required versions; repair the pair before retrying.")
    groups.append("nvidia-" + family)
    if distro in ("cachyos", "garuda"):
        subprocess.run(["pacman", "-Dk"], check=True, stdout=subprocess.DEVNULL)
    elif stem + "-dkms" not in installed:
        fixed = {kernel for kernel, package in {"linux": stem, "linux-lts": stem + "-lts"}.items() if package in installed}
        if not fixed:
            groups.append("nvidia-legacy-dkms" if family == "legacy" else "nvidia-open")
        else:
            for kernel in kernels:
                if kernel in fixed:
                    continue
                if family == "current" and kernel in ("linux", "linux-lts"):
                    groups.append("nvidia-open-linux" if kernel == "linux" else "nvidia-open-lts")
                else:
                    raise ValueError(f"Installed NVIDIA modules do not cover {kernel}; configure matching DKMS manually.")
    return groups, family, kernels


def verify_nvidia(family, kernels):
    utilities = "nvidia-580xx-utils" if family == "legacy" else "nvidia-utils"
    package = subprocess.run(["pacman", "-Q", utilities], check=True, capture_output=True, text=True).stdout.split()
    expected = package[1].split(":", 1)[-1].rsplit("-", 1)[0]
    for kernel in kernels:
        files = subprocess.run(["pacman", "-Qql", kernel], check=True, capture_output=True, text=True).stdout.splitlines()
        releases = {match[1] for name in files if (match := re.fullmatch(r"/usr/lib/modules/([^/]+)/pkgbase", name))}
        if len(releases) != 1:
            raise ValueError(f"Cannot identify one installed release for {kernel}; check its package files.")
        release = releases.pop()
        magic = subprocess.run(["modinfo", "-k", release, "-F", "vermagic", "nvidia"], capture_output=True, text=True)
        version = subprocess.run(["modinfo", "-k", release, "-F", "version", "nvidia"], capture_output=True, text=True)
        if magic.returncode or version.returncode or magic.stdout.split()[:1] != [release] or version.stdout.strip() != expected:
            raise ValueError(f"Missing or mismatched NVIDIA module for {kernel} ({release}), expected {expected}; repair it before rebooting.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--distro", required=True)
    parser.add_argument("--personal", action="store_true")
    args = parser.parse_args()
    file_sink = None
    try:
        file_sink = configure_logging()
        prepare_xdg()
        root = args.root.resolve()
        os.chdir(root)
        for name in ("MISE_CONFIG_FILE", "MISE_GLOBAL_CONFIG_FILE", "MISE_SYSTEM_CONFIG_FILE", "MISE_OVERRIDE_CONFIG_FILENAMES", "MISE_ENV"):
            os.environ.pop(name, None)
        os.environ.update(MISE_CONFIG_DIR="/dev/null", MISE_SYSTEM_CONFIG_DIR="/dev/null", MISE_AUTO_ENV="false",
                          MISE_CEILING_PATHS=str(root.parent), MISE_TRUSTED_CONFIG_PATHS=str(root / "mise"))
        setup_chaotic_aur()
        if not (shutil.which("yay") or shutil.which("paru")):
            subprocess.run(["mise", "--env", "aur-helper", "bootstrap", "packages", "apply", "--yes"], check=True)
            if not (shutil.which("yay") or shutil.which("paru")):
                raise ValueError("Mise did not provide an AUR helper; install yay or paru before retrying.")
        groups, family, kernels = ["packages"], None, []
        if args.personal:
            selected, family, kernels = personal_packages(args.distro.lower())
            groups.extend(selected)
        if family == "legacy":
            subprocess.run(["mise", "--env", "nvidia-legacy-utils", "bootstrap", "packages", "apply", "--yes"], check=True)
        subprocess.run(["mise", "--env", ",".join(groups), "bootstrap", "packages", "apply", "--yes"], check=True)
        if family and kernels:
            verify_nvidia(family, kernels)
        return 0
    except subprocess.CalledProcessError as error:
        logger.error("Package setup: {} failed (exit {}); correct the tool's error and retry.", error.cmd[0], error.returncode)
        return error.returncode
    except ValueError as error:
        logger.error("{}", str(error))
        return 1
    except OSError as error:
        try:
            logger.error("Package setup stopped (OS error {}); check required commands, XDG paths and log permissions.", error.errno)
        except OSError:
            if file_sink is not None:
                logger.remove(file_sink)
        return 1
    except KeyboardInterrupt:
        logger.warning("Package setup interrupted; rerun chezmoi apply when ready.")
        return 130


if __name__ == "__main__":
    status = main()
    sys.exit(status if status >= 0 else 128 - status)
