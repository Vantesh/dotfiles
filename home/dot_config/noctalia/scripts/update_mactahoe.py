#!/usr/bin/env python3
"""Recolor MacTahoe folders and apply the theme to GTK, QtEngine, and KDE."""

import colorsys
import fcntl
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from pathlib import Path

THEME = "MacTahoe-Noctalia"
STATE_FILE = ".noctalia-state.json"
SKIP = frozenset({"icon-theme.cache", ".whitesur-overlay", STATE_FILE})

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


def rgb(color):
    return tuple(int(color[i : i + 2], 16) / 255 for i in (1, 3, 5))


def lightness(color):
    channels = rgb(color)
    return (max(channels) + min(channels)) / 2


OFFSETS = {accent: lightness(accent) - lightness(BASE_ACCENT) for accent in ACCENTS[1:]}


@contextmanager
def locked(path):
    """Serialize updates without locking or modifying the theme itself."""
    with path.open("a+b") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def source_fingerprint(source):
    """Track source metadata without reading every icon's contents."""
    digest = hashlib.sha256()

    def record(path, name):
        info = path.lstat()
        digest.update(
            f"{name}\0{info.st_mode}:{info.st_size}:"
            f"{info.st_mtime_ns}:{info.st_ctime_ns}\0".encode()
        )

        if path.is_symlink():
            digest.update(os.fsencode(os.readlink(path)))
            digest.update(b"\0")

            try:
                target = path.stat()
            except OSError:
                digest.update(b"missing\0")
            else:
                digest.update(
                    f"{target.st_size}:{target.st_mtime_ns}:"
                    f"{target.st_ctime_ns}\0".encode()
                )

    def scan(directory, prefix):
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


def accent_colors(color):
    hue, base, saturation = colorsys.rgb_to_hls(*rgb(color))
    palette = {ACCENTS[0]: color}

    for accent, offset in OFFSETS.items():
        shade = colorsys.hls_to_rgb(
            hue,
            min(1, max(0, base + offset)),
            saturation,
        )
        palette[accent] = "#" + "".join(
            f"{round(channel * 255):02x}" for channel in shade
        )

    return palette


def atomic_write(path, content):
    """Replace a configuration file without exposing partial contents."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            delete=False,
        ) as handle:
            temporary = Path(handle.name)
            handle.write(content)

        if path.exists():
            temporary.chmod(stat.S_IMODE(path.stat().st_mode))
        else:
            temporary.chmod(0o600)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def folder_artwork(path):
    content = path.read_text(encoding="utf-8")

    if path.parent.name != "scalable" or path.resolve().name != "folder-projects.svg":
        return content

    projects = ET.fromstring(content)
    emblem = projects[-1]
    # Only replace the known alternate artwork; retain unfamiliar upstream designs.
    if emblem.tag != "{http://www.w3.org/2000/svg}path" or emblem.get("class") != "st0":
        return content

    base = ET.fromstring((path.parent / "folder.svg").read_text(encoding="utf-8"))
    base.append(emblem)
    # Some icon loaders require an unprefixed SVG root when detecting the format.
    ET.register_namespace("", "http://www.w3.org/2000/svg")
    return ET.tostring(base, encoding="unicode")


def generate_theme(source, target, state):
    palette = accent_colors(state["color"])
    matches = 0
    source_places = (source / "places").resolve()

    def copy_places(src, dst):
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

                if source_path.suffix.lower() == ".svg" and source_path.is_file():
                    updated, count = PATTERN.subn(
                        lambda match: palette[match.group().lower()],
                        folder_artwork(source_path),
                    )
                    matches += count

                    if count:
                        destination.write_text(updated, encoding="utf-8")
                        continue

                resolved = source_path.resolve()
                link = resolved

                # Preserve links within the generated places tree.
                if entry.is_symlink() and resolved.is_relative_to(source_places):
                    link = os.readlink(source_path)

                destination.symlink_to(link)

    with tempfile.TemporaryDirectory(
        prefix=".mactahoe-",
        dir=target.parent,
    ) as tmp:
        temporary = Path(tmp)
        staging = temporary / THEME
        staging.mkdir()

        for item in source.iterdir():
            if item.name in SKIP:
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

        previous = temporary / "previous"

        if target.exists() or target.is_symlink():
            target.rename(previous)

        try:
            staging.rename(target)
        except OSError:
            if previous.exists() or previous.is_symlink():
                previous.rename(target)
            raise

    print(
        f"Updated {THEME}: {state['color']} ({state['mode']})",
        flush=True,
    )


def select_gtk(source, regenerated):
    schema = "org.gnome.desktop.interface"

    def gsettings(verb, *args):
        return subprocess.run(
            ["gsettings", verb, schema, "icon-theme", *args],
            check=True,
            text=True,
            capture_output=verb == "get",
        ).stdout

    current = gsettings("get").strip().strip("'")

    if current == THEME and not regenerated:
        return

    if current == THEME:
        # Force an icon-theme change notification after regeneration.
        gsettings("set", source.name)

    gsettings("set", THEME)


def select_qtengine(config_dir, regenerated):
    path = config_dir / "qtengine/config.json"
    config = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}

    if not isinstance(config, dict):
        raise TypeError(f"QtEngine configuration must be a JSON object: {path}")

    settings = config.setdefault("theme", {})

    if not isinstance(settings, dict):
        raise TypeError(f"QtEngine theme settings must be a JSON object: {path}")

    if not regenerated and settings.get("iconTheme") == THEME:
        return

    settings["iconTheme"] = THEME
    atomic_write(
        path,
        json.dumps(config, indent=2, ensure_ascii=False) + "\n",
    )


def select_kde(config_dir):
    path = config_dir / "kdeglobals"

    if path.exists():
        section = KDE_ICONS_SECTION.search(path.read_text(encoding="utf-8"))

        if section and KDE_THEME_KEY.search(section.group(1)):
            return

    writer = shutil.which("kwriteconfig6")

    if writer:
        subprocess.run(
            [
                writer,
                "--file",
                str(path),
                "--group",
                "Icons",
                "--key",
                "Theme",
                THEME,
            ],
            check=True,
        )


def refresh_gtk_portal():
    """Refresh an idle portal; return False when a retry is needed."""
    if not shutil.which("hyprctl") or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return True

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


def main():
    if (
        len(sys.argv) != 3
        or not re.fullmatch(r"#[0-9a-fA-F]{6}", sys.argv[1])
        or sys.argv[2] not in ("dark", "light")
    ):
        raise ValueError("Usage: update_mactahoe.py <#rrggbb> <dark|light>")

    color, mode = sys.argv[1].lower(), sys.argv[2]

    icons = (
        Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "icons"
    )
    config_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")

    variant = mode

    candidates = (
        icons / f"MacTahoe-{variant}",
        icons / f"MacTahoe-blue-{variant}",
    )
    source = next(
        (path for path in candidates if (path / "index.theme").is_file()),
        None,
    )

    if source is None:
        raise FileNotFoundError(
            f"Install MacTahoe-{variant} (or MacTahoe-blue-{variant}) first"
        )

    target = icons / THEME

    # Hold the lock through generation and application.
    with locked(icons / f".{THEME}.lock"):
        state = {
            "color": color,
            "mode": mode,
            "source": str(source.resolve()),
            "stamp": source_fingerprint(source),
            "version": 11,
        }

        try:
            previous_state = json.loads(
                (target / STATE_FILE).read_text(encoding="utf-8")
            )
        except (OSError, ValueError):
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

        select_gtk(source, regenerated)
        select_qtengine(config_dir, regenerated)
        select_kde(config_dir)

        # Retry a refresh skipped for an open chooser without rebuilding icons.
        if pending_refresh.exists() and refresh_gtk_portal():
            pending_refresh.unlink()


if __name__ == "__main__":
    try:
        main()
    except (OSError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Cannot apply MacTahoe theme: {error}", file=sys.stderr)
        sys.exit(1)
