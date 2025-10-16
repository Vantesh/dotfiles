#!/usr/bin/env python3
"""
Tela Color Matcher - Find nearest Tela icon theme color.

Maps hex colors to the closest Tela icon theme color using perceptual
distance in HSL color space with caching support.
"""

import colorsys
import sys
from pathlib import Path
from typing import NamedTuple

# Tela icon theme color palette
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
    "black": "#4d4d4d",
}

# Perceptual weights for color distance calculation
DISTANCE_WEIGHTS = {
    "hue": 0.7,
    "saturation": 0.2,
    "lightness": 0.1,
}


class HSL(NamedTuple):
    """HSL color representation (Hue: 0-360, Saturation: 0-1, Lightness: 0-1)."""
    hue: float
    saturation: float
    lightness: float


# ============================================================================
# COLOR UTILITIES
# ============================================================================

def normalize_hex(hex_color: str) -> str:
    """
    Normalize hex color to lowercase 7-character format (#rrggbb).

    Args:
        hex_color: Hex color string (with or without # prefix)

    Returns:
        Normalized hex color string

    Raises:
        ValueError: If color format is invalid
    """
    trimmed = hex_color.strip()

    if not trimmed:
        raise ValueError("Hex color must be provided")

    if not trimmed.startswith("#"):
        trimmed = f"#{trimmed}"

    if len(trimmed) != 7:
        raise ValueError(f"Hex color must be 6 digits long: {hex_color!r}")

    try:
        int(trimmed[1:], 16)
    except ValueError as e:
        raise ValueError(f"Invalid hex color: {hex_color!r}") from e

    return trimmed.lower()


def hex_to_hsl(hex_color: str) -> HSL:
    """
    Convert hex color to HSL color space.

    Args:
        hex_color: Normalized hex color string

    Returns:
        HSL color tuple
    """
    normalized = normalize_hex(hex_color)

    # Parse RGB components
    r = int(normalized[1:3], 16) / 255.0
    g = int(normalized[3:5], 16) / 255.0
    b = int(normalized[5:7], 16) / 255.0

    # Convert to HLS (note: colorsys uses HLS, not HSL)
    h, l, s = colorsys.rgb_to_hls(r, g, b)

    return HSL(
        hue=h * 360.0,
        saturation=s,
        lightness=l,
    )


def calculate_distance(color_a: HSL, color_b: HSL) -> float:
    """
    Calculate perceptual distance between two colors in HSL space.

    Uses weighted Euclidean distance with special handling for hue circularity.
    Hue is weighted more heavily as it's more perceptually significant.

    Args:
        color_a: First HSL color
        color_b: Second HSL color

    Returns:
        Perceptual distance (0.0 = identical, higher = more different)
    """
    # Handle hue circularity (0° and 360° are the same)
    hue_delta = abs(color_a.hue - color_b.hue)
    hue_distance = min(hue_delta, 360.0 - hue_delta) / 180.0

    # Simple absolute differences for saturation and lightness
    saturation_distance = abs(color_a.saturation - color_b.saturation)
    lightness_distance = abs(color_a.lightness - color_b.lightness)

    # Weighted combination
    return (
        DISTANCE_WEIGHTS["hue"] * hue_distance +
        DISTANCE_WEIGHTS["saturation"] * saturation_distance +
        DISTANCE_WEIGHTS["lightness"] * lightness_distance
    )


# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

def load_from_cache(cache_path: Path, normalized_hex: str) -> str | None:
    """
    Load cached color name if available and valid.

    Args:
        cache_path: Path to cache file
        normalized_hex: Normalized hex color to check

    Returns:
        Cached color name if found, None otherwise
    """
    try:
        cached_contents = cache_path.read_text(encoding="utf-8")
    except (FileNotFoundError, OSError):
        return None

    lines = cached_contents.splitlines()
    if len(lines) < 2:
        return None

    cached_hex = lines[0].strip().lower()
    cached_name = lines[1].strip()

    if cached_hex == normalized_hex:
        return cached_name

    return None


def save_to_cache(cache_path: Path, normalized_hex: str, color_name: str) -> None:
    """
    Save color mapping to cache file.

    Args:
        cache_path: Path to cache file
        normalized_hex: Normalized hex color
        color_name: Tela color name
    """
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(
            f"{normalized_hex}\n{color_name}\n",
            encoding="utf-8",
        )
    except OSError:
        # Fail silently if caching is unavailable
        pass


# ============================================================================
# COLOR MATCHING
# ============================================================================

def find_nearest_tela_color(normalized_hex: str) -> str:
    """
    Find the nearest Tela color name for a given hex color.

    Args:
        normalized_hex: Normalized hex color string

    Returns:
        Name of the nearest Tela color

    Raises:
        RuntimeError: If no nearest color can be determined
    """
    input_hsl = hex_to_hsl(normalized_hex)
    nearest_name = None
    min_distance = float("inf")

    for name, hex_value in TELA_COLORS.items():
        tela_hsl = hex_to_hsl(hex_value)
        distance = calculate_distance(input_hsl, tela_hsl)

        if distance < min_distance:
            min_distance = distance
            nearest_name = name

    if nearest_name is None:
        raise RuntimeError("Unable to resolve nearest Tela color")

    return nearest_name


def resolve_color(hex_color: str, cache_path: Path) -> str:
    """
    Resolve hex color to nearest Tela color name with caching.

    Args:
        hex_color: Input hex color (normalized internally)
        cache_path: Path to cache file

    Returns:
        Name of the nearest Tela color

    Raises:
        ValueError: If hex color format is invalid
        RuntimeError: If color resolution fails
    """
    normalized_hex = normalize_hex(hex_color)

    # Try cache first
    cached = load_from_cache(cache_path, normalized_hex)
    if cached:
        return cached

    # Compute and cache result
    nearest = find_nearest_tela_color(normalized_hex)
    save_to_cache(cache_path, normalized_hex, nearest)

    return nearest


# ============================================================================
# CLI
# ============================================================================

def parse_arguments() -> tuple[str, Path]:
    """
    Parse and validate command-line arguments.

    Returns:
        Tuple of (hex_color, cache_path)
    """
    if len(sys.argv) != 3:
        print(
            "Usage: nearest_tela_color.py <hex_color> <cache_path>",
            file=sys.stderr,
        )
        print(
            "\nExample: nearest_tela_color.py '#5677fc' ~/.cache/tela_color",
            file=sys.stderr,
        )
        sys.exit(1)

    hex_color = sys.argv[1]
    cache_path = Path(sys.argv[2]).expanduser()

    return hex_color, cache_path


def main() -> int:
    """Main entry point."""
    hex_color, cache_path = parse_arguments()

    try:
        nearest = resolve_color(hex_color, cache_path)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2

    print(nearest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
