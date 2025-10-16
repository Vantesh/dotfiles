#!/usr/bin/env python3
"""
Terminal color palette generator supporting chromatic and grayscale modes.
Generates 16-color palettes with contrast optimization for light/dark themes.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import NamedTuple

# Type aliases
HexColor = str

# Constants
DEFAULT_LIGHT_BG = "#f8f8f8"
DEFAULT_DARK_BG = "#1a1a1a"
WAL_CACHE_PATH = Path.home() / ".cache" / "wal" / "colors.json"

CATPPUCCIN_ANCHORS = {
    "red_light": "#d20f39",
    "green_light": "#40a02b",
    "yellow_light": "#df8e1d",
    "red_dark": "#f38ba8",
    "green_dark": "#8bd5a1",
    "yellow_dark": "#dba63a",
}


# ============================================================================
# DATA STRUCTURES
# ============================================================================

class GrayscaleTintSpec(NamedTuple):
    """Specification for tinting grayscale colors."""
    hue: float
    saturation_factor: float
    blend_ratio: float
    min_contrast: float


@dataclass(frozen=True)
class ColorTransform:
    """Defines transformations to apply to HSV color values."""
    saturation_multiplier: float | None = None
    saturation_floor: float | None = None
    static_saturation: float | None = None
    value_multiplier: float | None = None
    value_floor: float | None = None
    value_ceiling: float | None = None
    static_value: float | None = None


# ============================================================================
# CONFIGURATION CLASSES
# ============================================================================

class GrayscaleConfigBase:
    """Base configuration for grayscale palette generation."""
    ACCENT_MIN_CONTRAST = 4.5
    BRIGHT_MIN_CONTRAST = 3.0
    NEUTRAL_MIN_CONTRAST = 4.5
    FOREGROUND_MIN_CONTRAST = 6.0


class GrayscaleLightConfig(GrayscaleConfigBase):
    """Configuration for light mode grayscale palettes."""
    VALUE_FLOOR = 0.32
    VALUE_CEILING = 0.9
    ACCENT_SATURATION = 0.4
    BRIGHT_SATURATION_DELTA = 0.16
    ACCENT_VALUE_MULTIPLIER = 1.14
    ACCENT_VALUE_MIN = 0.47
    ACCENT_VALUE_MAX = 0.985
    BRIGHT_VALUE_OFFSET = 0.28
    BRIGHT_VALUE_MIN = 0.6
    BRIGHT_VALUE_MIN_FLOOR_OFFSET = None
    BRIGHT_VALUE_MAX = 0.995
    NEUTRAL_DARKER_BLEND = 0.45
    NEUTRAL_LIGHTER_BLEND = 0.65
    FOREGROUND_HEX = "#101010"

    ACCENT_SPECS = (
        GrayscaleTintSpec(0.0, 1.0, 0.2, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.92, 0.18, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.97, 0.19, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.88, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 0.95, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.9, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
    )

    BRIGHT_SPECS = (
        GrayscaleTintSpec(0.0, 0.94, 0.1, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.86, 0.08, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.91, 0.09, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.8, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 0.88, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.84, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
    )


class GrayscaleDarkConfig(GrayscaleConfigBase):
    """Configuration for dark mode grayscale palettes."""
    VALUE_FLOOR = 0.28
    VALUE_CEILING = 0.92
    ACCENT_SATURATION = 0.26
    BRIGHT_SATURATION_DELTA = 0.1
    ACCENT_VALUE_MULTIPLIER = 0.98
    ACCENT_VALUE_MIN = 0.32
    ACCENT_VALUE_MAX = 0.9
    BRIGHT_VALUE_OFFSET = 0.18
    BRIGHT_VALUE_MIN = None
    BRIGHT_VALUE_MIN_FLOOR_OFFSET = 0.06
    BRIGHT_VALUE_MAX = 0.96
    NEUTRAL_DARKER_BLEND = 0.65
    NEUTRAL_LIGHTER_BLEND = 0.4
    FOREGROUND_HEX = "#f6f6f6"

    ACCENT_SPECS = (
        GrayscaleTintSpec(0.0, 1.08, 0.42, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.98, 0.4, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 1.02, 0.41, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.88, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 1.02, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.92, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
    )

    BRIGHT_SPECS = (
        GrayscaleTintSpec(0.0, 1.02, 0.32, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.92, 0.3, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.98, 0.3, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.86, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 1.0, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.9, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
    )


class ChromaticConfigBase:
    """Base configuration for chromatic palette generation."""
    RED_HUE = 0.0
    GREEN_HUE = 0.33
    YELLOW_HUE = 0.08
    CYAN_HUE_SHIFT = 0.08
    MAGENTA_HUE_SHIFT = 0.03
    MAGENTA_WRAP_AROUND = 1.0 - MAGENTA_HUE_SHIFT
    DARK_CYAN_ADDITIONAL_SHIFT = 0.02
    MIN_CONTRAST_MAIN = 4.5
    MIN_CONTRAST_BRIGHT = 3.0


class ChromaticLightConfig(ChromaticConfigBase):
    """Configuration for light mode chromatic palettes."""
    BLEND_RATIO_COMMON = 0.6
    BLEND_RATIO_GREEN = 0.6
    BLEND_RATIO_YELLOW = 0.6
    RED_ANCHOR_KEY = "red_light"
    GREEN_ANCHOR_KEY = "green_light"
    YELLOW_ANCHOR_KEY = "yellow_light"
    FINAL_CONTRAST_HEX = "#1a1a1a"
    NEUTRAL_INSERTS = ("#2e2e2e", "#4a4a4a")

    # Color transformations
    RED = ColorTransform(static_saturation=0.75, static_value=0.85)
    BRIGHT_RED = ColorTransform(static_saturation=0.6, static_value=0.9)
    GREEN = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.75, value_multiplier=0.6)
    BRIGHT_GREEN = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.7, value_multiplier=0.65)
    YELLOW = ColorTransform(saturation_multiplier=0.85, saturation_floor=0.7, value_multiplier=0.7)
    BRIGHT_YELLOW = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.65, value_multiplier=0.75)
    BLUE = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.7, value_multiplier=1.1)
    BRIGHT_BLUE = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.7, value_multiplier=1.3, value_ceiling=1.0)
    BRIGHT_BLUE_HONOR = ColorTransform(saturation_multiplier=1.1, value_multiplier=1.2, value_ceiling=1.0)
    MAGENTA = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.6, value_multiplier=0.9)
    MAGENTA_HONOR = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.7, value_multiplier=0.85)
    BRIGHT_MAGENTA = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.75, value_multiplier=1.25, value_ceiling=1.0)
    CYAN = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.65, value_multiplier=1.05)
    BRIGHT_CYAN = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.65, value_multiplier=1.25, value_ceiling=1.0)


class ChromaticDarkConfig(ChromaticConfigBase):
    """Configuration for dark mode chromatic palettes."""
    BLEND_RATIO_COMMON = 0.5
    BLEND_RATIO_GREEN = 0.75
    BLEND_RATIO_YELLOW = 0.35
    RED_ANCHOR_KEY = "red_dark"
    GREEN_ANCHOR_KEY = "green_dark"
    YELLOW_ANCHOR_KEY = "yellow_dark"
    FINAL_CONTRAST_HEX = "#ffffff"
    NEUTRAL_INSERTS = ("#abb2bf", "#5c6370")

    # Color transformations
    RED = ColorTransform(static_saturation=0.6, static_value=0.8)
    BRIGHT_RED = ColorTransform(static_saturation=0.45, static_value=0.9)
    GREEN = ColorTransform(saturation_multiplier=0.65, saturation_floor=0.5, value_multiplier=0.9)
    BRIGHT_GREEN = ColorTransform(saturation_multiplier=0.5, saturation_floor=0.4, value_multiplier=1.5, value_ceiling=0.9)
    YELLOW = ColorTransform(saturation_multiplier=0.5, saturation_floor=0.45, value_multiplier=1.4)
    BRIGHT_YELLOW = ColorTransform(saturation_multiplier=0.4, saturation_floor=0.35, value_multiplier=1.6, value_ceiling=0.95)
    BLUE = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.6, value_multiplier=1.6, value_ceiling=1.0)
    BRIGHT_BLUE = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.5, value_ceiling=0.9)
    BRIGHT_BLUE_HONOR = ColorTransform(saturation_multiplier=1.2, value_multiplier=1.1, value_ceiling=1.0)
    MAGENTA = ColorTransform(saturation_multiplier=0.7, saturation_floor=0.6, value_multiplier=0.85)
    MAGENTA_HONOR = ColorTransform(saturation_multiplier=0.8, value_multiplier=0.75)
    BRIGHT_MAGENTA = ColorTransform(saturation_multiplier=0.7, saturation_floor=0.6, value_multiplier=1.3, value_ceiling=0.9)
    CYAN = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.25, value_ceiling=0.85)
    BRIGHT_CYAN = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.2, value_ceiling=0.85)


# ============================================================================
# COLOR UTILITY FUNCTIONS
# ============================================================================

@lru_cache(maxsize=256)
def hex_to_rgb(hex_color: HexColor) -> tuple[float, float, float]:
    """Convert hex color to RGB tuple (0.0-1.0 range)."""
    hex_color = hex_color.strip().lstrip('#').lower()
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return r, g, b


def rgb_to_hex(r: float, g: float, b: float) -> HexColor:
    """Convert RGB tuple (0.0-1.0 range) to hex color."""
    r = max(0, min(1, r))
    g = max(0, min(1, g))
    b = max(0, min(1, b))
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"


def normalize_hex(hex_color: HexColor | None) -> HexColor | None:
    """Normalize hex color format."""
    if not hex_color or not hex_color.strip():
        return None
    hex_color = hex_color.strip()
    if not hex_color.startswith('#'):
        hex_color = f"#{hex_color}"
    return hex_color.lower()


def clamp(value: float, lower: float, upper: float) -> float:
    """Clamp value between lower and upper bounds."""
    return max(lower, min(upper, value))


def wrap_hue(hue: float) -> float:
    """Wrap hue value to [0.0, 1.0] range."""
    if hue < 0.0:
        return hue + 1.0
    if hue > 1.0:
        return hue - 1.0
    return hue


def is_grayscale(hex_color: HexColor, tolerance: float = 0.01) -> bool:
    """Check if color is grayscale within tolerance."""
    normalized = normalize_hex(hex_color)
    if not normalized:
        return False
    r, g, b = hex_to_rgb(normalized)
    span = max(abs(r - g), abs(r - b), abs(g - b))
    return span <= tolerance


def to_grayscale(hex_color: HexColor) -> HexColor:
    """Convert color to grayscale using luminance."""
    normalized = normalize_hex(hex_color)
    if not normalized:
        return "#808080"
    r, g, b = hex_to_rgb(normalized)
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return rgb_to_hex(luminance, luminance, luminance)


def blend_colors(color_a: HexColor, color_b: HexColor, ratio: float) -> HexColor:
    """Blend two colors. ratio=1.0 favors color_a, 0.0 favors color_b."""
    r_a, g_a, b_a = hex_to_rgb(color_a)
    r_b, g_b, b_b = hex_to_rgb(color_b)
    r = r_a * ratio + r_b * (1 - ratio)
    g = g_a * ratio + g_b * (1 - ratio)
    b = b_a * ratio + b_b * (1 - ratio)
    return rgb_to_hex(r, g, b)


@lru_cache(maxsize=256)
def calculate_luminance(hex_color: HexColor) -> float:
    """Calculate relative luminance for WCAG contrast."""
    r, g, b = hex_to_rgb(hex_color)

    def linearize(channel: float) -> float:
        return channel / 12.92 if channel <= 0.03928 else ((channel + 0.055) / 1.055) ** 2.4

    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


@lru_cache(maxsize=256)
def contrast_ratio(fg: HexColor, bg: HexColor) -> float:
    """Calculate WCAG contrast ratio between foreground and background."""
    lum_fg = calculate_luminance(fg)
    lum_bg = calculate_luminance(bg)
    lighter = max(lum_fg, lum_bg)
    darker = min(lum_fg, lum_bg)
    return (lighter + 0.05) / (darker + 0.05)


def ensure_contrast(
    color: HexColor,
    background: HexColor,
    min_ratio: float = 4.5,
    is_light: bool = False,
) -> HexColor:
    """Adjust color value to meet minimum contrast ratio."""
    if contrast_ratio(color, background) >= min_ratio:
        return color

    r, g, b = hex_to_rgb(color)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    # Try darkening first in light mode, lightening first in dark mode
    directions = (-1, 1) if is_light else (1, -1)

    for step in range(1, 30):
        delta = step * 0.02
        for direction in directions:
            new_v = clamp(v + direction * delta, 0.0, 1.0)
            if new_v == v:
                continue
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(h, s, new_v))
            if contrast_ratio(candidate, background) >= min_ratio:
                return candidate

    return color


def apply_color_transform(
    transform: ColorTransform,
    saturation: float,
    value: float,
) -> tuple[float, float]:
    """Apply color transformation to HSV saturation and value."""
    # Transform saturation
    if transform.static_saturation is not None:
        s = transform.static_saturation
    else:
        s = saturation
        if transform.saturation_multiplier is not None:
            s *= transform.saturation_multiplier
        if transform.saturation_floor is not None:
            s = max(s, transform.saturation_floor)

    # Transform value
    if transform.static_value is not None:
        v = transform.static_value
    else:
        v = value
        if transform.value_multiplier is not None:
            v *= transform.value_multiplier
        if transform.value_floor is not None:
            v = max(v, transform.value_floor)
        if transform.value_ceiling is not None:
            v = min(v, transform.value_ceiling)

    return clamp(s, 0.0, 1.0), clamp(v, 0.0, 1.0)


# ============================================================================
# WAL CACHE INTEGRATION
# ============================================================================

def read_wal_colors(cache_path: Path = WAL_CACHE_PATH) -> tuple[HexColor | None, HexColor | None, HexColor | None]:
    """Read (primary, primary_container, background) from wal cache."""
    try:
        with cache_path.open() as f:
            data = json.load(f)
    except Exception:
        return None, None, None

    primary = data.get('primary')
    primary_container = data.get('primary_container')
    background = data.get('background')

    if background is None:
        background = (data.get('special') or {}).get('background')

    if primary is None or primary_container is None:
        colors = data.get('colors') or {}
        primary = primary or colors.get('color4') or colors.get('color12')
        primary_container = primary_container or colors.get('color5') or colors.get('color13')

    return normalize_hex(primary), normalize_hex(primary_container), normalize_hex(background)


def read_ghostty_colors(cache_path: Path = WAL_CACHE_PATH) -> dict[str, HexColor]:
    """Read Ghostty-compatible colors from wal cache."""
    try:
        with cache_path.open() as f:
            data = json.load(f)
    except Exception:
        return {}

    def pick(*keys: str, default: HexColor | None = None) -> HexColor | None:
        for key in keys:
            value = data.get(key)
            if isinstance(value, str) and value:
                return value if value.startswith('#') else f"#{value}"
        return default

    special = data.get('special') or {}

    bg = pick('background') or normalize_hex(special.get('background'))
    fg = pick('foreground') or normalize_hex(special.get('foreground'))
    cursor = pick('cursor-color', 'cursor_color', 'cursor', default=fg)
    cursor_text = pick('cursor-text', 'cursor_text', default=fg)
    sel_bg = pick('selection-background', 'selection_background', default=bg)
    sel_fg = pick('selection-foreground', 'selection_foreground', default=fg)

    result = {}
    if bg:
        result['background'] = bg
    if fg:
        result['foreground'] = fg
    if cursor:
        result['cursor-color'] = cursor
    if cursor_text:
        result['cursor-text'] = cursor_text
    if sel_bg:
        result['selection-background'] = sel_bg
    if sel_fg:
        result['selection-foreground'] = sel_fg

    return result


# ============================================================================
# PALETTE GENERATION
# ============================================================================

def generate_grayscale_palette(
    base: HexColor,
    is_light: bool,
    honor_primary: HexColor | None,
    background: HexColor,
) -> list[HexColor]:
    """Generate 16-color grayscale palette."""
    palette = [background]
    config = GrayscaleLightConfig if is_light else GrayscaleDarkConfig

    # Determine base grayscale value
    ref = honor_primary or base
    gray = to_grayscale(ref)
    base_v = colorsys.rgb_to_hsv(*hex_to_rgb(gray))[2]
    base_v = clamp(base_v, config.VALUE_FLOOR, config.VALUE_CEILING)

    # Calculate accent and bright values
    accent_sat = config.ACCENT_SATURATION
    bright_sat = accent_sat + config.BRIGHT_SATURATION_DELTA
    accent_v = clamp(
        base_v * config.ACCENT_VALUE_MULTIPLIER,
        config.ACCENT_VALUE_MIN,
        config.ACCENT_VALUE_MAX,
    )

    bright_v_min = config.BRIGHT_VALUE_MIN
    if bright_v_min is None and config.BRIGHT_VALUE_MIN_FLOOR_OFFSET is not None:
        bright_v_min = config.VALUE_FLOOR + config.BRIGHT_VALUE_MIN_FLOOR_OFFSET
    if bright_v_min is None:
        bright_v_min = 0.0

    bright_v = clamp(
        accent_v + config.BRIGHT_VALUE_OFFSET,
        bright_v_min,
        config.BRIGHT_VALUE_MAX,
    )

    def tinted_accent(h: float, s: float, v: float, blend: float, min_c: float) -> HexColor:
        rgb = colorsys.hsv_to_rgb(h, s, v)
        accent = rgb_to_hex(*rgb)
        blended = blend_colors(gray, accent, clamp(blend, 0.0, 1.0))
        return ensure_contrast(blended, background, min_c, is_light)

    # Generate accent colors (indices 1-6)
    for spec in config.ACCENT_SPECS:
        palette.append(tinted_accent(
            spec.hue,
            accent_sat * spec.saturation_factor,
            accent_v,
            spec.blend_ratio,
            spec.min_contrast,
        ))

    # Generate neutrals (indices 7-8)
    neutral_dark = blend_colors('#000000', gray, config.NEUTRAL_DARKER_BLEND)
    neutral_light = blend_colors('#ffffff', gray, config.NEUTRAL_LIGHTER_BLEND)
    palette.append(ensure_contrast(neutral_dark, background, config.NEUTRAL_MIN_CONTRAST, is_light))
    palette.append(ensure_contrast(neutral_light, background, config.NEUTRAL_MIN_CONTRAST, is_light))

    # Generate bright colors (indices 9-14)
    for spec in config.BRIGHT_SPECS:
        palette.append(tinted_accent(
            spec.hue,
            bright_sat * spec.saturation_factor,
            bright_v,
            spec.blend_ratio,
            spec.min_contrast,
        ))

    # Foreground (index 15)
    palette.append(ensure_contrast(
        config.FOREGROUND_HEX,
        background,
        config.FOREGROUND_MIN_CONTRAST,
        is_light,
    ))

    return palette


def generate_chromatic_palette(
    base: HexColor,
    is_light: bool,
    honor_primary: HexColor | None,
    background: HexColor,
) -> list[HexColor]:
    """Generate 16-color chromatic palette."""
    palette = [background]
    config = ChromaticLightConfig if is_light else ChromaticDarkConfig

    # Parse base color
    r, g, b = hex_to_rgb(base)
    base_h, base_s, base_v = colorsys.rgb_to_hsv(r, g, b)

    # Parse honor primary if provided
    honor_h = honor_s = honor_v = None
    if honor_primary:
        r, g, b = hex_to_rgb(honor_primary)
        honor_h, honor_s, honor_v = colorsys.rgb_to_hsv(r, g, b)

    # Helper to generate and blend color
    def gen_color(hue: float, transform: ColorTransform, anchor_key: str | None = None, blend_ratio: float = 0.0) -> HexColor:
        s, v = apply_color_transform(transform, base_s, base_v)
        color = rgb_to_hex(*colorsys.hsv_to_rgb(hue, s, v))
        if anchor_key:
            color = blend_colors(CATPPUCCIN_ANCHORS[anchor_key], color, blend_ratio)
        return ensure_contrast(color, background, config.MIN_CONTRAST_MAIN, is_light)

    # Generate main colors (indices 1-6)
    palette.append(gen_color(config.RED_HUE, config.RED, config.RED_ANCHOR_KEY, config.BLEND_RATIO_COMMON))
    palette.append(gen_color(config.GREEN_HUE, config.GREEN, config.GREEN_ANCHOR_KEY, config.BLEND_RATIO_GREEN))
    palette.append(gen_color(config.YELLOW_HUE, config.YELLOW, config.YELLOW_ANCHOR_KEY, config.BLEND_RATIO_YELLOW))
    palette.append(gen_color(base_h, config.BLUE))

    # Magenta (with honor primary support)
    magenta_h = wrap_hue(base_h - config.MAGENTA_HUE_SHIFT)
    if honor_primary and honor_h is not None and honor_s is not None and honor_v is not None:
        s, v = apply_color_transform(config.MAGENTA_HONOR, honor_s, honor_v)
        magenta = rgb_to_hex(*colorsys.hsv_to_rgb(honor_h, s, v))
    else:
        s, v = apply_color_transform(config.MAGENTA, base_s, base_v)
        magenta = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_h, s, v))
    palette.append(ensure_contrast(magenta, background, config.MIN_CONTRAST_MAIN, is_light))

    # Cyan (with honor primary support)
    cyan_h = wrap_hue(base_h + config.CYAN_HUE_SHIFT)
    if honor_primary:
        cyan = honor_primary
    else:
        s, v = apply_color_transform(config.CYAN, base_s, base_v)
        cyan = rgb_to_hex(*colorsys.hsv_to_rgb(cyan_h, s, v))
    palette.append(ensure_contrast(cyan, background, config.MIN_CONTRAST_MAIN, is_light))

    # Neutral inserts (indices 7-8)
    palette.extend(config.NEUTRAL_INSERTS)

    # Helper for bright colors
    def gen_bright(hue: float, transform: ColorTransform, anchor_key: str | None = None, blend_ratio: float = 0.0) -> HexColor:
        s, v = apply_color_transform(transform, base_s, base_v)
        color = rgb_to_hex(*colorsys.hsv_to_rgb(hue, s, v))
        if anchor_key:
            color = blend_colors(CATPPUCCIN_ANCHORS[anchor_key], color, blend_ratio)
        return ensure_contrast(color, background, config.MIN_CONTRAST_BRIGHT, is_light)

    # Generate bright colors (indices 9-14)
    palette.append(gen_bright(config.RED_HUE, config.BRIGHT_RED, config.RED_ANCHOR_KEY, config.BLEND_RATIO_COMMON))
    palette.append(gen_bright(config.GREEN_HUE, config.BRIGHT_GREEN, config.GREEN_ANCHOR_KEY, config.BLEND_RATIO_GREEN))
    palette.append(gen_bright(config.YELLOW_HUE, config.BRIGHT_YELLOW, config.YELLOW_ANCHOR_KEY, config.BLEND_RATIO_YELLOW))

    # Bright blue (with honor primary support)
    if honor_primary and honor_h is not None and honor_s is not None and honor_v is not None:
        s, v = apply_color_transform(config.BRIGHT_BLUE_HONOR, honor_s, honor_v)
        bright_blue = rgb_to_hex(*colorsys.hsv_to_rgb(honor_h, s, v))
    else:
        s, v = apply_color_transform(config.BRIGHT_BLUE, base_s, base_v)
        bright_blue = rgb_to_hex(*colorsys.hsv_to_rgb(base_h, s, v))
    palette.append(ensure_contrast(bright_blue, background, config.MIN_CONTRAST_BRIGHT, is_light))

    # Bright magenta
    s, v = apply_color_transform(config.BRIGHT_MAGENTA, base_s, base_v)
    bright_magenta = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_h, s, v))
    palette.append(ensure_contrast(bright_magenta, background, config.MIN_CONTRAST_BRIGHT, is_light))

    # Bright cyan
    bright_cyan_h = cyan_h if is_light else wrap_hue(base_h + config.DARK_CYAN_ADDITIONAL_SHIFT)
    s, v = apply_color_transform(config.BRIGHT_CYAN, base_s, base_v)
    bright_cyan = rgb_to_hex(*colorsys.hsv_to_rgb(bright_cyan_h, s, v))
    palette.append(ensure_contrast(bright_cyan, background, config.MIN_CONTRAST_BRIGHT, is_light))

    # Final contrast color (index 15)
    palette.append(config.FINAL_CONTRAST_HEX)

    return palette


def generate_palette(
    base: HexColor,
    is_light: bool = False,
    honor_primary: HexColor | None = None,
    background: HexColor | None = None,
    grayscale: bool = False,
) -> list[HexColor]:
    """Generate 16-color palette from base color."""
    base = normalize_hex(base) or "#808080"
    honor_primary = normalize_hex(honor_primary)
    background = normalize_hex(background)

    # Resolve background
    bg = background or (DEFAULT_LIGHT_BG if is_light else DEFAULT_DARK_BG)

    # Choose generation mode
    if grayscale:
        return generate_grayscale_palette(base, is_light, honor_primary, bg)
    return generate_chromatic_palette(base, is_light, honor_primary, bg)


# ============================================================================
# CLI
# ============================================================================

def parse_arguments(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate 16-color palettes from base hues.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "base_hex",
        nargs="?",
        help="Base hex color (e.g. #1f6feb)",
    )

    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--light",
        action="store_true",
        help="Generate light mode palette",
    )
    mode_group.add_argument(
        "--dark",
        action="store_true",
        help="Generate dark mode palette",
    )

    parser.add_argument(
        "--ghostty",
        action="store_true",
        help="Output Ghostty configuration format instead of Kitty",
    )
    parser.add_argument(
        "--honor-primary",
        dest="honor_primary",
        metavar="HEX",
        help="Hex color to honor for magenta/cyan balance",
    )
    parser.add_argument(
        "--background",
        metavar="HEX",
        help="Override background hex color",
    )

    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    args = parse_arguments(argv if argv is not None else sys.argv[1:])

    # Parse arguments
    base = normalize_hex(args.base_hex)
    is_light = args.light
    if args.dark:
        is_light = False
    use_ghostty = args.ghostty
    honor_primary = normalize_hex(args.honor_primary)
    background = normalize_hex(args.background)

    # Read wal cache
    wal_primary, wal_primary_container, wal_background = read_wal_colors()

    # Fallback to wal colors
    if honor_primary is None and wal_primary:
        honor_primary = wal_primary
    if background is None and wal_background:
        background = wal_background

    # Determine base color
    if base is None:
        if wal_primary_container:
            base = wal_primary_container
        elif honor_primary:
            base = honor_primary
        else:
            print(
                "Usage: dank16.py [<base_hex>] [--light|--dark] [--ghostty] "
                "[--honor-primary HEX] [--background HEX]",
                file=sys.stderr,
            )
            print(
                "Error: No base color provided and couldn't read from ~/.cache/wal/colors.json",
                file=sys.stderr,
            )
            return 1

    # Determine grayscale mode
    grayscale = False
    if is_grayscale(base):
        candidates = [c for c in (honor_primary, wal_primary) if c]
        grayscale = all(is_grayscale(c) for c in candidates) if candidates else True

    # Auto-detect light/dark mode from background
    if not args.light and not args.dark and background:
        is_light = calculate_luminance(background) > 0.75

    # Generate palette
    palette = generate_palette(base, is_light, honor_primary, background, grayscale)

    # Output
    if not use_ghostty:
        for i, color in enumerate(palette[:16]):
            print(f"color{i}   {color}")
    else:
        ghostty_extras = read_ghostty_colors()
        for key in (
            'background',
            'foreground',
            'cursor-color',
            'cursor-text',
            'selection-background',
            'selection-foreground',
        ):
            if key in ghostty_extras:
                print(f"{key} = {ghostty_extras[key]}")
        for i, color in enumerate(palette[:16]):
            print(f"palette = {i}={color}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
