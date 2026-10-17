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
from contextlib import contextmanager
from pathlib import Path

THEME = "MacTahoe-Noctalia"
STATE_FILE = ".noctalia-state.json"
SKIP = frozenset({"icon-theme.cache", ".whitesur-overlay", STATE_FILE})

ACCENTS = ("#006efd", "#88ccf2", "#67b1de", "#7cc1ea", "#56a1d3")
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
                        source_path.read_text(encoding="utf-8"),
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

    # Intentional inverted mapping.
    variant = "light" if mode == "dark" else "dark"

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
            "version": 5,
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

        if regenerated:
            generate_theme(source, target, state)

        select_gtk(source, regenerated)
        select_qtengine(config_dir, regenerated)
        select_kde(config_dir)


if __name__ == "__main__":
    try:
        main()
    except (OSError, TypeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Cannot apply MacTahoe theme: {error}", file=sys.stderr)
        sys.exit(1)
