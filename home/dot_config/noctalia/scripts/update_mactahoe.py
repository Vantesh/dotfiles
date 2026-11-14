#!/usr/bin/env python3
"""Recolor MacTahoe folders and apply the theme to GTK and KDE apps (Dolphin etc.).

Requires Python 3.14.

The recolored theme is built next to the real one and swapped in atomically
(Linux renameat2 RENAME_EXCHANGE), so applications never see a missing theme.
Qt apps using QtEngine read the icon theme name from their static,
chezmoi-managed config, which already names MacTahoe-Noctalia, so this script
does not touch it.
"""

import colorsys
import ctypes
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections.abc import Callable, Generator
from contextlib import contextmanager
from pathlib import Path

THEME = "MacTahoe-Noctalia"
STATE_FILE = ".noctalia-state.json"

# Derived from this file, so any code change regenerates the theme.
with Path(__file__).open("rb") as _script:
    SCRIPT_VERSION = hashlib.file_digest(_script, "sha256").hexdigest()[:12]

SVG_NS = "http://www.w3.org/2000/svg"

ACCENTS = (
    "#006efd",
    "#88ccf2",
    "#67b1de",
    "#7cc1ea",
    "#56a1d3",
    # Alternate folder artwork, including Projects, uses this blue palette.
    "#60c0f0",
    "#83d4fb",
    "#46a2d7",
    "#008ea2",
)
BASE_ACCENT = "#7cc1ea"


PATTERN = re.compile("|".join(map(re.escape, ACCENTS)), re.IGNORECASE)
NAME_LINE = re.compile(r"^Name=.*$", re.MULTILINE)
KDE_ICONS_SECTION = re.compile(r"(?ms)^\[Icons\][ \t]*\r?\n(.*?)(?=^\[|\Z)")
KDE_THEME_KEY = re.compile(rf"(?m)^Theme[ \t]*=[ \t]*{re.escape(THEME)}[ \t]*\r?$")


def rgb(color: str) -> tuple[float, float, float]:
    return (
        int(color[1:3], 16) / 255,
        int(color[3:5], 16) / 255,
        int(color[5:7], 16) / 255,
    )


def lightness(color: str) -> float:
    channels = rgb(color)
    return (max(channels) + min(channels)) / 2


OFFSETS = {accent: lightness(accent) - lightness(BASE_ACCENT) for accent in ACCENTS[1:]}

# Shades sit at base + offset. Clamping the base keeps the darkest and lightest
# shades distinct instead of collapsing to black or white for extreme accents.
MIN_BASE = 0.02 - min(OFFSETS.values())
MAX_BASE = 0.80


@contextmanager
def locked(directory: Path) -> Generator[None]:
    """Serialize updates. The icons directory itself is the lock, so no lock
    file is created; closing the descriptor releases it."""
    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield
    finally:
        os.close(descriptor)


def source_fingerprint(source: Path) -> str:
    """Track source metadata without reading every icon's contents."""
    digest = hashlib.sha256()

    def record(path: Path, name: str) -> None:
        info = path.lstat()
        digest.update(f"{name}\0{info.st_mode}:{info.st_size}:{info.st_mtime_ns}\0".encode())

        if path.is_symlink():
            digest.update(os.fsencode(path.readlink()))
            digest.update(b"\0")

            try:
                target = path.stat()
            except OSError:
                digest.update(b"missing\0")
            else:
                digest.update(f"{target.st_size}:{target.st_mtime_ns}\0".encode())

    def scan(directory: Path, prefix: str) -> None:
        with os.scandir(directory) as entries:
            for entry in sorted(entries, key=lambda item: item.name):
                path = Path(entry.path)
                name = prefix + entry.name

                record(path, name)

                if entry.is_dir(follow_symlinks=False):
                    scan(path, name + "/")

    record(source / "index.theme", "index.theme")
    scan(source / "places", "places/")
    return digest.hexdigest()


def accent_colors(color: str) -> dict[str, str]:
    hue, base, saturation = colorsys.rgb_to_hls(*rgb(color))
    base = min(MAX_BASE, max(MIN_BASE, base))
    palette = {ACCENTS[0]: color}

    for accent, offset in OFFSETS.items():
        shade = colorsys.hls_to_rgb(
            hue,
            min(1.0, max(0.0, base + offset)),
            saturation,
        )
        palette[accent] = "#" + "".join(f"{round(channel * 255):02x}" for channel in shade)

    return palette


def folder_artwork(path: Path) -> str:
    content = path.read_text(encoding="utf-8")

    if path.parent.name != "scalable" or path.resolve().name != "folder-projects.svg":
        return content

    try:
        projects = ET.fromstring(content)
        emblem = projects[-1]
        # Only replace the known alternate artwork; retain unfamiliar upstream designs.
        if emblem.tag != f"{{{SVG_NS}}}path" or emblem.get("class") != "st0":
            return content

        base = ET.fromstring((path.parent / "folder.svg").read_text(encoding="utf-8"))
    except (ET.ParseError, IndexError, OSError) as error:
        print(f"Keeping upstream {path.name}: {error}", file=sys.stderr)
        return content

    base.append(emblem)
    # Some icon loaders require an unprefixed SVG root when detecting the format.
    ET.register_namespace("", SVG_NS)
    return ET.tostring(base, encoding="unicode")


def swap_in(staging: Path, target: Path) -> None:
    """Put `staging` at `target`; the previous theme is left at `staging`.

    renameat2(RENAME_EXCHANGE) swaps the two directories atomically, so the
    theme never disappears. Fails if the filesystem does not support it.
    """
    if not target.exists():
        staging.rename(target)
        return

    at_fdcwd, rename_exchange = -100, 2  # linux/fcntl.h, linux/fs.h
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    if renameat2(at_fdcwd, os.fsencode(staging), at_fdcwd, os.fsencode(target), rename_exchange):
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), str(target))


def generate_theme(source: Path, target: Path, state: dict[str, str]) -> None:
    """Build the recolored theme and swap it into place as `target`."""
    palette = accent_colors(state["color"])
    matches = 0
    source_places = (source / "places").resolve()

    with tempfile.TemporaryDirectory(prefix=".mactahoe-", dir=target.parent) as tmp:
        staging = Path(tmp) / THEME
        staging.mkdir()
        staging_places = staging / "places"

        def copy_places(src: Path, dst: Path) -> None:
            """Copy the directory tree without following directory symlinks."""
            nonlocal matches
            dst.mkdir()

            with os.scandir(src) as entries:
                for entry in entries:
                    source_path = Path(entry.path)
                    destination = dst / entry.name

                    if entry.is_dir(follow_symlinks=False):
                        copy_places(source_path, destination)
                        continue

                    resolved = source_path.resolve()

                    if entry.is_symlink() and resolved.is_relative_to(source_places):
                        # Keep links inside the tree relative; the target is
                        # recolored in its own pass, so no duplicate artwork.
                        inside = staging_places / resolved.relative_to(source_places)
                        destination.symlink_to(inside.relative_to(dst, walk_up=True))
                        continue

                    if source_path.suffix.lower() == ".svg" and source_path.is_file():
                        updated, count = PATTERN.subn(
                            lambda match: palette[match.group().lower()],
                            folder_artwork(source_path),
                        )
                        matches += count

                        if count:
                            destination.write_text(updated, encoding="utf-8")
                            continue

                    destination.symlink_to(resolved)

        for item in source.iterdir():
            if item.name == "icon-theme.cache":  # rebuilt below for the new theme
                continue

            destination = staging / item.name

            if item.name == "index.theme":
                content = NAME_LINE.sub(
                    f"Name={THEME}",
                    item.read_text(encoding="utf-8"),
                )
                destination.write_text(content, encoding="utf-8")

            elif item.name == "places":
                copy_places(item, destination)

            elif item.name == "places@2x":
                destination.symlink_to("places")

            else:
                destination.symlink_to(item.resolve())

        # Projects otherwise falls back to full-color artwork at sidebar sizes.
        for size in ("16", "22", "24", "symbolic"):
            directory = staging / "places" / size
            suffix = "-symbolic.svg" if size == "symbolic" else ".svg"
            projects = directory / f"folder-projects{suffix}"
            code = directory / f"folder-code{suffix}"
            if not projects.exists() and not projects.is_symlink() and code.is_file():
                projects.symlink_to(code.name)

        if not matches:
            raise ValueError(f"No supported folder accents found in {source}")

        subprocess.run(
            ["gtk-update-icon-cache", "--force", "--quiet", str(staging)],
            check=True,
        )

        (staging / STATE_FILE).write_text(
            json.dumps(state, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

        swap_in(staging, target)  # the old theme ends up in `tmp` and is deleted

    print(f"Updated {THEME}: {state['color']} ({state['mode']})", flush=True)


def select_gtk(source: Path, regenerated: bool) -> None:
    schema = "org.gnome.desktop.interface"

    def gsettings(verb: str, *args: str) -> str:
        return (
            subprocess.run(
                ["gsettings", verb, schema, "icon-theme", *args],
                check=True,
                text=True,
                capture_output=verb == "get",
            ).stdout
            or ""
        )

    current = gsettings("get").strip().strip("'")

    if current == THEME and not regenerated:
        return

    if current == THEME:
        # Force an icon-theme change notification after regeneration.
        gsettings("set", source.name)

    gsettings("set", THEME)


def notify_kde_icons() -> None:
    """Best effort: tell running KDE apps to reload icons (KIconLoader signal)."""
    sender = shutil.which("dbus-send")
    if not sender:
        return

    for group in range(6):  # Desktop, Toolbar, MainToolbar, Small, Panel, Dialog
        subprocess.run(
            [
                sender,
                "--session",
                "--type=signal",
                "/KIconLoader",
                "org.kde.KIconLoader.iconChanged",
                f"int32:{group}",
            ],
            check=False,
            capture_output=True,
            timeout=5,
        )


def select_kde(config_dir: Path, regenerated: bool) -> None:
    """Point KDE Frameworks apps (Dolphin, Gwenview, ...) at the theme.

    This only needs the KDE libraries, not a KDE desktop session.
    """
    path = config_dir / "kdeglobals"
    configured = False

    if path.exists():
        section = KDE_ICONS_SECTION.search(path.read_text(encoding="utf-8"))
        configured = bool(section and KDE_THEME_KEY.search(section.group(1)))

    if not configured:
        if writer := shutil.which("kwriteconfig6"):
            subprocess.run(
                [writer, "--file", str(path), "--group", "Icons", "--key", "Theme", THEME],
                check=True,
            )
        else:
            print("kwriteconfig6 not found: KDE apps will not follow the theme", file=sys.stderr)

    if regenerated:
        notify_kde_icons()


def hyprland_signature() -> str | None:
    """Find the running Hyprland instance even when the environment lacks it."""
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if signature:
        return signature

    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    try:
        sockets = sorted(
            (runtime / "hypr").glob("*/.socket.sock"),
            key=lambda socket: socket.stat().st_mtime,
        )
    except OSError:
        return None

    return sockets[-1].parent.name if sockets else None


def refresh_gtk_portal() -> bool:
    """Refresh an idle portal; return False when a retry is needed."""
    if not shutil.which("hyprctl"):
        return True

    signature = hyprland_signature()
    if signature is None:
        return True  # No Hyprland session, so there is no portal window to check.

    env = {**os.environ, "HYPRLAND_INSTANCE_SIGNATURE": signature}

    try:
        result = subprocess.run(
            [
                "systemctl",
                "--user",
                "show",
                "xdg-desktop-portal-gtk.service",
                "--property=MainPID",
                "--value",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        pid = int(result.stdout.strip())
        if pid <= 0:
            return True

        result = subprocess.run(
            ["hyprctl", "-j", "clients"],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
            env=env,
        )
        clients = json.loads(result.stdout)
        if not isinstance(clients, list) or any(
            not isinstance(client, dict) or not isinstance(client.get("pid"), int)
            for client in clients
        ):
            return False
        # Include unfocused, hidden, and other-workspace dialogs too.
        if any(client["pid"] == pid for client in clients):
            print("Skipping GTK portal refresh: a portal window is open", flush=True)
            return False

        subprocess.run(
            ["systemctl", "--user", "try-restart", "xdg-desktop-portal-gtk.service"],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
        return True
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Skipping GTK portal refresh: {error}", file=sys.stderr)
        return False


def main() -> int:
    if (
        len(sys.argv) != 3
        or not re.fullmatch(r"#[0-9a-fA-F]{6}", sys.argv[1])
        or sys.argv[2] not in ("dark", "light")
    ):
        sys.exit("Usage: update_mactahoe.py <#rrggbb> <dark|light>")

    color, mode = sys.argv[1].lower(), sys.argv[2]

    icons = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "icons"
    config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")

    candidates = (
        icons / f"MacTahoe-{mode}",
        icons / f"MacTahoe-blue-{mode}",
    )
    source = next(
        (path for path in candidates if (path / "index.theme").is_file()),
        None,
    )

    if source is None:
        raise FileNotFoundError(f"Install MacTahoe-{mode} (or MacTahoe-blue-{mode}) first")

    target = icons / THEME
    errors: list[str] = []

    def step(name: str, action: Callable[[], object]) -> None:
        """Run one apply step; a failure must not block the others."""
        try:
            action()
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            errors.append(f"{name}: {error}")

    # Hold the lock through generation and application.
    with locked(icons):
        # Leftovers from interrupted runs; safe to remove while holding the lock.
        for stale in icons.glob(".mactahoe-*"):
            shutil.rmtree(stale, ignore_errors=True)

        state = {
            "color": color,
            "mode": mode,
            "source": str(source.resolve()),
            "stamp": source_fingerprint(source),
            "version": SCRIPT_VERSION,
        }

        try:
            previous_state = json.loads((target / STATE_FILE).read_text(encoding="utf-8"))
        except OSError, ValueError:
            previous_state = None

        regenerated = (
            previous_state != state
            or not (target / "index.theme").is_file()
            or not (target / "icon-theme.cache").is_file()
        )

        pending_refresh = icons / f".{THEME}.gtk-refresh"
        if regenerated:
            generate_theme(source, target, state)
            pending_refresh.touch()

        step("GTK", lambda: select_gtk(source, regenerated))
        step("KDE", lambda: select_kde(config_dir, regenerated))

        # Retry a refresh skipped for an open chooser without rebuilding icons.
        if pending_refresh.exists() and refresh_gtk_portal():
            pending_refresh.unlink()

    for error in errors:
        print(f"Cannot apply MacTahoe theme: {error}", file=sys.stderr)

    return 1 if errors else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Cannot apply MacTahoe theme: {error}", file=sys.stderr)
        sys.exit(1)
