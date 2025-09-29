#!/usr/bin/env python3

import colorsys
import sys
from pathlib import Path

TELA_COLORS = {
    "nord": "#4d576a",
    "grey": "#bdbdbd",
    "purple": "#7e57c2",
    "brown": "#795548",
    "dark": "#5294e2",
    "red": "#ef5350",
    "manjaro": "#16a085",
    "orange": "#e18908",
    "blue": "#5677fc",
    "pink": "#f06292",
    "ubuntu": "#fb8441",
    "green": "#66bb6a",
    "dracula": "#44475a",
    "yellow": "#ffca28",
    "black": "#4D4D4D",
}

def normalize_hex(hex_color):
    trimmed = hex_color.strip()
    if not trimmed:
        raise ValueError("hex color must be provided")
    if not trimmed.startswith("#"):
        trimmed = f"#{trimmed}"
    if len(trimmed) != 7:
        raise ValueError(f"hex color must be 6 digits long: {hex_color!r}")

    try:
        int(trimmed[1:], 16)
    except ValueError as exc:
        raise ValueError(f"invalid hex color: {hex_color!r}") from exc

    return trimmed.lower()


def hex_to_hsl(hex_color):
    normalized = normalize_hex(hex_color)
    red = int(normalized[1:3], 16) / 255.0
    green = int(normalized[3:5], 16) / 255.0
    blue = int(normalized[5:7], 16) / 255.0
    hue, lightness, saturation = colorsys.rgb_to_hls(red, green, blue)
    return hue * 360.0, saturation, lightness


def color_distance(a, b):
    hue_delta = abs(a[0] - b[0])
    hue_distance = min(hue_delta, 360.0 - hue_delta) / 180.0
    saturation_distance = abs(a[1] - b[1])
    lightness_distance = abs(a[2] - b[2])
    return 0.7 * hue_distance + 0.2 * saturation_distance + 0.1 * lightness_distance


def load_cached(cache_path, normalized_hex):
    try:
        cached_contents = cache_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None
    except OSError:
        return None

    try:
        cached_hex, cached_name, *_ = cached_contents.splitlines()
    except ValueError:
        return None

    if cached_hex.strip().lower() == normalized_hex:
        return cached_name.strip()

    return None


def store_cache(cache_path, normalized_hex, name):
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(f"{normalized_hex}\n{name}\n", encoding="utf-8")
    except OSError:
        pass


def compute_nearest_color(normalized_hex):
    input_hsl = hex_to_hsl(normalized_hex)
    nearest_name = None
    min_distance = float("inf")

    for name, hex_value in TELA_COLORS.items():
        tela_hsl = hex_to_hsl(hex_value)
        distance = color_distance(input_hsl, tela_hsl)
        if distance < min_distance:
            min_distance = distance
            nearest_name = name

    if nearest_name is None:
        raise RuntimeError("Unable to resolve nearest Tela color")

    return nearest_name


def resolve_nearest_color(hex_color, cache_path):
    normalized_hex = normalize_hex(hex_color)

    cached = load_cached(cache_path, normalized_hex)
    if cached:
        return cached

    nearest = compute_nearest_color(normalized_hex)
    store_cache(cache_path, normalized_hex, nearest)
    return nearest


def main():
    if len(sys.argv) != 3:
        print("Usage: nearest_tela_color.py <hex> <cache_path>", file=sys.stderr)
        return 1

    cache_path = Path(sys.argv[2]).expanduser()

    try:
        nearest = resolve_nearest_color(sys.argv[1], cache_path)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 2

    print(nearest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
