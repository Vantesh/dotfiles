#!/usr/bin/env python3
from __future__ import annotations

import argparse
import colorsys
import json
import sys
from functools import lru_cache
from pathlib import Path
from typing import NamedTuple

HexColor = str

DEFAULT_LIGHT_BACKGROUND: HexColor = "#f8f8f8"
DEFAULT_DARK_BACKGROUND: HexColor = "#1a1a1a"

CATPPUCCIN_ANCHORS: dict[str, HexColor] = {
    "red_light": "#d20f39",
    "green_light": "#40a02b",
    "yellow_light": "#df8e1d",
    "red_dark": "#f38ba8",
    "green_dark": "#8bd5a1",
    "yellow_dark": "#dba63a",
}

WAL_CACHE_PATH: Path = Path.home() / ".cache" / "wal" / "colors.json"


class GrayscaleTintSpec(NamedTuple):
    hue: float
    saturation_factor: float
    blend_ratio: float
    min_contrast: float


class GrayscaleConfigBase:
    ACCENT_MIN_CONTRAST: float = 4.5
    BRIGHT_MIN_CONTRAST: float = 3.0
    NEUTRAL_MIN_CONTRAST: float = 4.5
    FOREGROUND_MIN_CONTRAST: float = 6.0


class GrayscaleLightConfig(GrayscaleConfigBase):
    VALUE_FLOOR: float = 0.32
    VALUE_CEILING: float = 0.9
    ACCENT_SATURATION: float = 0.4
    BRIGHT_SATURATION_DELTA: float = 0.16
    ACCENT_VALUE_MULTIPLIER: float = 1.14
    ACCENT_VALUE_MIN: float = 0.47
    ACCENT_VALUE_MAX: float = 0.985
    BRIGHT_VALUE_OFFSET: float = 0.28
    BRIGHT_VALUE_MIN: float = 0.6
    BRIGHT_VALUE_MIN_FLOOR_OFFSET: float | None = None
    BRIGHT_VALUE_MAX: float = 0.995
    ACCENT_SPECS: tuple[GrayscaleTintSpec, ...] = (
        GrayscaleTintSpec(0.0, 1.0, 0.2, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.92, 0.18, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.97, 0.19, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.88, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 0.95, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.9, 0.26, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
    )
    BRIGHT_SPECS: tuple[GrayscaleTintSpec, ...] = (
        GrayscaleTintSpec(0.0, 0.94, 0.1, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.86, 0.08, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.91, 0.09, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.8, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 0.88, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.84, 0.18, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
    )
    NEUTRAL_DARKER_BLEND: float = 0.45
    NEUTRAL_LIGHTER_BLEND: float = 0.65
    FOREGROUND_HEX: HexColor = "#101010"


class GrayscaleDarkConfig(GrayscaleConfigBase):
    VALUE_FLOOR: float = 0.28
    VALUE_CEILING: float = 0.92
    ACCENT_SATURATION: float = 0.26
    BRIGHT_SATURATION_DELTA: float = 0.1
    ACCENT_VALUE_MULTIPLIER: float = 0.98
    ACCENT_VALUE_MIN: float = 0.32
    ACCENT_VALUE_MAX: float = 0.9
    BRIGHT_VALUE_OFFSET: float = 0.18
    BRIGHT_VALUE_MIN: float | None = None
    BRIGHT_VALUE_MIN_FLOOR_OFFSET: float | None = 0.06
    BRIGHT_VALUE_MAX: float = 0.96
    ACCENT_SPECS: tuple[GrayscaleTintSpec, ...] = (
        GrayscaleTintSpec(0.0, 1.08, 0.42, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.98, 0.4, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 1.02, 0.41, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.88, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 1.02, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.92, 0.48, GrayscaleConfigBase.ACCENT_MIN_CONTRAST),
    )
    BRIGHT_SPECS: tuple[GrayscaleTintSpec, ...] = (
        GrayscaleTintSpec(0.0, 1.02, 0.32, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.33, 0.92, 0.3, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.16, 0.98, 0.3, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.58, 0.86, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.83, 1.0, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
        GrayscaleTintSpec(0.5, 0.9, 0.36, GrayscaleConfigBase.BRIGHT_MIN_CONTRAST),
    )
    NEUTRAL_DARKER_BLEND: float = 0.65
    NEUTRAL_LIGHTER_BLEND: float = 0.4
    FOREGROUND_HEX: HexColor = "#f6f6f6"


class ColorTransform(NamedTuple):
    saturation_multiplier: float | None = None
    saturation_floor: float | None = None
    static_saturation: float | None = None
    value_multiplier: float | None = None
    value_floor: float | None = None
    value_ceiling: float | None = None
    static_value: float | None = None


class ChromaticConfigBase:
    RED_HUE: float = 0.0
    GREEN_HUE: float = 0.33
    YELLOW_HUE: float = 0.08
    CYAN_HUE_SHIFT: float = 0.08
    MAGENTA_HUE_SHIFT: float = 0.03
    MAGENTA_WRAP_AROUND: float = 1.0 - MAGENTA_HUE_SHIFT
    DARK_CYAN_ADDITIONAL_SHIFT: float = 0.02
    MIN_CONTRAST_MAIN: float = 4.5
    MIN_CONTRAST_BRIGHT: float = 3.0


class ChromaticLightConfig(ChromaticConfigBase):
    BLEND_RATIO_COMMON: float = 0.6
    BLEND_RATIO_GREEN: float = BLEND_RATIO_COMMON
    BLEND_RATIO_YELLOW: float = BLEND_RATIO_COMMON
    RED_ANCHOR_KEY: str = "red_light"
    GREEN_ANCHOR_KEY: str = "green_light"
    YELLOW_ANCHOR_KEY: str = "yellow_light"
    RED: ColorTransform = ColorTransform(static_saturation=0.75, static_value=0.85)
    BRIGHT_RED: ColorTransform = ColorTransform(static_saturation=0.6, static_value=0.9)
    GREEN: ColorTransform = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.75, value_multiplier=0.6)
    BRIGHT_GREEN: ColorTransform = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.7, value_multiplier=0.65)
    YELLOW: ColorTransform = ColorTransform(saturation_multiplier=0.85, saturation_floor=0.7, value_multiplier=0.7)
    BRIGHT_YELLOW: ColorTransform = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.65, value_multiplier=0.75)
    BLUE: ColorTransform = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.7, value_multiplier=1.1)
    BRIGHT_BLUE: ColorTransform = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.7, value_multiplier=1.3, value_ceiling=1.0)
    BRIGHT_BLUE_HONOR: ColorTransform = ColorTransform(saturation_multiplier=1.1, value_multiplier=1.2, value_ceiling=1.0)
    MAGENTA: ColorTransform = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.6, value_multiplier=0.9)
    MAGENTA_HONOR: ColorTransform = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.7, value_multiplier=0.85)
    BRIGHT_MAGENTA: ColorTransform = ColorTransform(saturation_multiplier=0.9, saturation_floor=0.75, value_multiplier=1.25, value_ceiling=1.0)
    CYAN: ColorTransform = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.65, value_multiplier=1.05)
    BRIGHT_CYAN: ColorTransform = ColorTransform(saturation_multiplier=0.75, saturation_floor=0.65, value_multiplier=1.25, value_ceiling=1.0)
    NEUTRAL_INSERTS: tuple[HexColor, HexColor] = ("#2e2e2e", "#4a4a4a")
    FINAL_CONTRAST_HEX: HexColor = "#1a1a1a"


class ChromaticDarkConfig(ChromaticConfigBase):
    BLEND_RATIO_COMMON: float = 0.5
    BLEND_RATIO_GREEN: float = 0.75
    BLEND_RATIO_YELLOW: float = 0.35
    RED_ANCHOR_KEY: str = "red_dark"
    GREEN_ANCHOR_KEY: str = "green_dark"
    YELLOW_ANCHOR_KEY: str = "yellow_dark"
    RED: ColorTransform = ColorTransform(static_saturation=0.6, static_value=0.8)
    BRIGHT_RED: ColorTransform = ColorTransform(static_saturation=0.45, static_value=0.9)
    GREEN: ColorTransform = ColorTransform(saturation_multiplier=0.65, saturation_floor=0.5, value_multiplier=0.9)
    BRIGHT_GREEN: ColorTransform = ColorTransform(saturation_multiplier=0.5, saturation_floor=0.4, value_multiplier=1.5, value_ceiling=0.9)
    YELLOW: ColorTransform = ColorTransform(saturation_multiplier=0.5, saturation_floor=0.45, value_multiplier=1.4)
    BRIGHT_YELLOW: ColorTransform = ColorTransform(saturation_multiplier=0.4, saturation_floor=0.35, value_multiplier=1.6, value_ceiling=0.95)
    BLUE: ColorTransform = ColorTransform(saturation_multiplier=0.8, saturation_floor=0.6, value_multiplier=1.6, value_ceiling=1.0)
    BRIGHT_BLUE: ColorTransform = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.5, value_ceiling=0.9)
    BRIGHT_BLUE_HONOR: ColorTransform = ColorTransform(saturation_multiplier=1.2, value_multiplier=1.1, value_ceiling=1.0)
    MAGENTA: ColorTransform = ColorTransform(saturation_multiplier=0.7, saturation_floor=0.6, value_multiplier=0.85)
    MAGENTA_HONOR: ColorTransform = ColorTransform(saturation_multiplier=0.8, value_multiplier=0.75)
    BRIGHT_MAGENTA: ColorTransform = ColorTransform(saturation_multiplier=0.7, saturation_floor=0.6, value_multiplier=1.3, value_ceiling=0.9)
    CYAN: ColorTransform = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.25, value_ceiling=0.85)
    BRIGHT_CYAN: ColorTransform = ColorTransform(saturation_multiplier=0.6, saturation_floor=0.5, value_multiplier=1.2, value_ceiling=0.85)
    NEUTRAL_INSERTS: tuple[HexColor, HexColor] = ("#abb2bf", "#5c6370")
    FINAL_CONTRAST_HEX: HexColor = "#ffffff"


@lru_cache(maxsize=256)
def hex_to_rgb(hex_color: HexColor) -> tuple[float, float, float]:
    hex_color = hex_color.strip().lower()
    if hex_color.startswith('#'):
        hex_color = hex_color[1:]
    red = int(hex_color[0:2], 16) / 255.0
    green = int(hex_color[2:4], 16) / 255.0
    blue = int(hex_color[4:6], 16) / 255.0
    return red, green, blue

def rgb_to_hex(red: float, green: float, blue: float) -> HexColor:
    red = max(0, min(1, red))
    green = max(0, min(1, green))
    blue = max(0, min(1, blue))
    return f"#{int(red*255):02x}{int(green*255):02x}{int(blue*255):02x}"


def normalize_hex(hex_color: HexColor | None) -> HexColor | None:
    if not hex_color:
        return None
    hex_color = hex_color.strip()
    if not hex_color:
        return None
    if not hex_color.startswith('#'):
        hex_color = f"#{hex_color}"
    return hex_color.lower()


def clamp(value: float, lower: float, upper: float) -> float:
    if value < lower:
        return lower
    if value > upper:
        return upper
    return value


def apply_color_transform(transform: ColorTransform, saturation: float, value: float) -> tuple[float, float]:
    if transform.static_saturation is not None:
        saturation_result = transform.static_saturation
    else:
        saturation_result = saturation
        if transform.saturation_multiplier is not None:
            saturation_result *= transform.saturation_multiplier
        if transform.saturation_floor is not None:
            saturation_result = max(saturation_result, transform.saturation_floor)

    if transform.static_value is not None:
        value_result = transform.static_value
    else:
        value_result = value
        if transform.value_multiplier is not None:
            value_result *= transform.value_multiplier
        if transform.value_floor is not None:
            value_result = max(value_result, transform.value_floor)
        if transform.value_ceiling is not None:
            value_result = min(value_result, transform.value_ceiling)

    return clamp(saturation_result, 0.0, 1.0), clamp(value_result, 0.0, 1.0)


def wrap_hue(hue: float) -> float:
    if hue < 0.0:
        return hue + 1.0
    if hue > 1.0:
        return hue - 1.0
    return hue


def is_grayscale_hex(hex_color: HexColor, tolerance: float = 0.01) -> bool:
    normalized = normalize_hex(hex_color)
    if not normalized:
        return False
    red, green, blue = hex_to_rgb(normalized)
    channel_span = max(abs(red - green), abs(red - blue), abs(green - blue))
    return channel_span <= tolerance


def to_grayscale_hex(hex_color: HexColor) -> HexColor:
    normalized = normalize_hex(hex_color)
    if not normalized:
        return "#808080"
    red, green, blue = hex_to_rgb(normalized)
    luminance_value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return rgb_to_hex(luminance_value, luminance_value, luminance_value)


def blend_hex(hex_color_a: HexColor, hex_color_b: HexColor, blend_ratio: float) -> HexColor:
    """Blend two hex colors. ratio=1.0 favors color_a, 0.0 favors color_b."""
    red_a, green_a, blue_a = hex_to_rgb(hex_color_a)
    red_b, green_b, blue_b = hex_to_rgb(hex_color_b)
    red_mix = red_a * blend_ratio + red_b * (1 - blend_ratio)
    green_mix = green_a * blend_ratio + green_b * (1 - blend_ratio)
    blue_mix = blue_a * blend_ratio + blue_b * (1 - blend_ratio)
    return rgb_to_hex(red_mix, green_mix, blue_mix)

@lru_cache(maxsize=256)
def luminance(hex_color: HexColor) -> float:
    red, green, blue = hex_to_rgb(hex_color)
    def srgb_to_linear(channel: float) -> float:
        return channel/12.92 if channel <= 0.03928 else ((channel + 0.055)/1.055) ** 2.4
    return 0.2126 * srgb_to_linear(red) + 0.7152 * srgb_to_linear(green) + 0.0722 * srgb_to_linear(blue)

@lru_cache(maxsize=256)
def contrast_ratio(hex_foreground: HexColor, hex_background: HexColor) -> float:
    lum_foreground = luminance(hex_foreground)
    lum_background = luminance(hex_background)
    lighter = max(lum_foreground, lum_background)
    darker = min(lum_foreground, lum_background)
    return (lighter + 0.05) / (darker + 0.05)

def ensure_contrast(
    hex_color: HexColor,
    hex_background: HexColor,
    min_ratio: float = 4.5,
    is_light_mode: bool = False,
) -> HexColor:
    current_ratio = contrast_ratio(hex_color, hex_background)
    if current_ratio >= min_ratio:
        return hex_color

    red, green, blue = hex_to_rgb(hex_color)
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)

    step_directions = (-1, 1) if is_light_mode else (1, -1)

    for step_index in range(1, 30):
        delta_value = step_index * 0.02
        for direction in step_directions:
            new_value = clamp(value + direction * delta_value, 0.0, 1.0)
            if new_value == value:
                continue
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(hue, saturation, new_value))
            if contrast_ratio(candidate, hex_background) >= min_ratio:
                return candidate

    return hex_color


def read_wal_colors(cache_path: Path = WAL_CACHE_PATH) -> tuple[HexColor | None, HexColor | None, HexColor | None]:
    """Return `(primary, primary_container, background)` from wal cache if present."""
    try:
        with cache_path.open() as file_handle:
            data = json.load(file_handle)
    except Exception:
        return None, None, None

    primary_hex: HexColor | None = data.get('primary')
    primary_container_hex: HexColor | None = data.get('primary_container')
    background_hex: HexColor | None = data.get('background')

    if background_hex is None:
        background_hex = (data.get('special') or {}).get('background')

    if (primary_hex is None) or (primary_container_hex is None):
        colors_obj = data.get('colors') or {}
        primary_hex = primary_hex or colors_obj.get('color4') or colors_obj.get('color12')
        primary_container_hex = primary_container_hex or colors_obj.get('color5') or colors_obj.get('color13')

    return (
        normalize_hex(primary_hex),
        normalize_hex(primary_container_hex),
        normalize_hex(background_hex),
    )


def read_ghostty_colors(cache_path: Path = WAL_CACHE_PATH) -> dict[str, HexColor]:
    """Return Ghostty-compatible color overrides from wal cache if present."""
    try:
        with cache_path.open() as fh:
            data = json.load(fh)
    except Exception:
        return {}

    def pick(*keys: str, default: HexColor | None = None) -> HexColor | None:
        for key in keys:
            value = data.get(key)
            if isinstance(value, str) and value:
                return value if value.startswith('#') else f"#{value}"
        return default

    special_block = data.get('special') or {}

    background = pick('background')
    if background is None:
        background = normalize_hex(special_block.get('background'))

    foreground = pick('foreground')
    if foreground is None:
        foreground = normalize_hex(special_block.get('foreground'))

    cursor_color = pick('cursor-color', 'cursor_color', 'cursor', default=foreground)
    cursor_text = pick('cursor-text', 'cursor_text', default=foreground)
    sel_bg = pick('selection-background', 'selection_background', default=background)
    sel_fg = pick('selection-foreground', 'selection_foreground', default=foreground)

    result: dict[str, HexColor] = {}
    if background:
        result['background'] = background
    if foreground:
        result['foreground'] = foreground
    if cursor_color:
        result['cursor-color'] = cursor_color
    if cursor_text:
        result['cursor-text'] = cursor_text
    if sel_bg:
        result['selection-background'] = sel_bg
    if sel_fg:
        result['selection-foreground'] = sel_fg
    return result

def generate_palette(
    base_hex_color: HexColor,
    is_light_mode: bool = False,
    honor_primary_hex: HexColor | None = None,
    background_hex: HexColor | None = None,
    grayscale_mode: bool = False,
) -> list[HexColor]:
    normalized_base = normalize_hex(base_hex_color) or "#808080"
    normalized_primary = normalize_hex(honor_primary_hex)
    normalized_background = normalize_hex(background_hex)

    resolved_background = normalized_background or (
        DEFAULT_LIGHT_BACKGROUND if is_light_mode else DEFAULT_DARK_BACKGROUND
    )

    if grayscale_mode:
        return generate_grayscale_palette(
            normalized_base,
            is_light_mode,
            normalized_primary,
            resolved_background,
        )

    return generate_chromatic_palette(
        normalized_base,
        is_light_mode,
        normalized_primary,
        resolved_background,
    )


def generate_grayscale_palette(
    base_hex_color: HexColor,
    is_light_mode: bool,
    honor_primary_hex: HexColor | None,
    resolved_background_hex: HexColor,
) -> list[HexColor]:
    palette_hex_list: list[HexColor] = [resolved_background_hex]

    config = GrayscaleLightConfig if is_light_mode else GrayscaleDarkConfig

    reference_hex = honor_primary_hex or base_hex_color
    base_gray_hex = to_grayscale_hex(reference_hex)
    base_value = colorsys.rgb_to_hsv(*hex_to_rgb(base_gray_hex))[2]
    value_floor = config.VALUE_FLOOR
    value_ceiling = config.VALUE_CEILING
    base_value = clamp(base_value, value_floor, value_ceiling)

    accent_saturation = config.ACCENT_SATURATION
    bright_saturation = accent_saturation + config.BRIGHT_SATURATION_DELTA
    accent_value = clamp(
        base_value * config.ACCENT_VALUE_MULTIPLIER,
        config.ACCENT_VALUE_MIN,
        config.ACCENT_VALUE_MAX,
    )
    bright_value_min = config.BRIGHT_VALUE_MIN
    if bright_value_min is None and config.BRIGHT_VALUE_MIN_FLOOR_OFFSET is not None:
        bright_value_min = value_floor + config.BRIGHT_VALUE_MIN_FLOOR_OFFSET
    if bright_value_min is None:
        bright_value_min = 0.0
    bright_value = clamp(
        accent_value + config.BRIGHT_VALUE_OFFSET,
        bright_value_min,
        config.BRIGHT_VALUE_MAX,
    )

    def tinted_accent(
        hue: float,
        saturation: float,
        value: float,
        base_blend: float,
        min_contrast: float,
    ) -> HexColor:
        rgb = colorsys.hsv_to_rgb(hue, saturation, value)
        accent_hex = rgb_to_hex(*rgb)
        blended_hex = blend_hex(base_gray_hex, accent_hex, clamp(base_blend, 0.0, 1.0))
        return ensure_contrast(blended_hex, resolved_background_hex, min_contrast, is_light_mode)

    for spec in config.ACCENT_SPECS:
        palette_hex_list.append(
            tinted_accent(
                spec.hue,
                accent_saturation * spec.saturation_factor,
                accent_value,
                spec.blend_ratio,
                spec.min_contrast,
            )
        )

    neutral_darker = blend_hex('#000000', base_gray_hex, config.NEUTRAL_DARKER_BLEND)
    neutral_lighter = blend_hex('#ffffff', base_gray_hex, config.NEUTRAL_LIGHTER_BLEND)
    palette_hex_list.append(
        ensure_contrast(neutral_darker, resolved_background_hex, config.NEUTRAL_MIN_CONTRAST, is_light_mode)
    )
    palette_hex_list.append(
        ensure_contrast(neutral_lighter, resolved_background_hex, config.NEUTRAL_MIN_CONTRAST, is_light_mode)
    )

    for spec in config.BRIGHT_SPECS:
        palette_hex_list.append(
            tinted_accent(
                spec.hue,
                bright_saturation * spec.saturation_factor,
                bright_value,
                spec.blend_ratio,
                spec.min_contrast,
            )
        )

    foreground_candidate = config.FOREGROUND_HEX
    palette_hex_list.append(
        ensure_contrast(
            foreground_candidate,
            resolved_background_hex,
            config.FOREGROUND_MIN_CONTRAST,
            is_light_mode,
        )
    )
    return palette_hex_list


def generate_chromatic_palette(
    base_hex_color: HexColor,
    is_light_mode: bool,
    honor_primary_hex: HexColor | None,
    resolved_background_hex: HexColor,
) -> list[HexColor]:
    palette_hex_list: list[HexColor] = [resolved_background_hex]

    config = ChromaticLightConfig if is_light_mode else ChromaticDarkConfig

    base_red, base_green, base_blue = hex_to_rgb(base_hex_color)
    base_hue, base_saturation, base_value = colorsys.rgb_to_hsv(base_red, base_green, base_blue)

    catppuccin = CATPPUCCIN_ANCHORS

    blend_ratio_common = config.BLEND_RATIO_COMMON
    blend_ratio_green = config.BLEND_RATIO_GREEN
    blend_ratio_yellow = config.BLEND_RATIO_YELLOW

    honor_hue = honor_saturation = honor_value = None
    if honor_primary_hex:
        honor_red, honor_green, honor_blue = hex_to_rgb(honor_primary_hex)
        honor_hue, honor_saturation, honor_value = colorsys.rgb_to_hsv(honor_red, honor_green, honor_blue)

    red_saturation, red_value = apply_color_transform(config.RED, base_saturation, base_value)
    red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(config.RED_HUE, red_saturation, red_value))
    red_blended_hex = blend_hex(catppuccin[config.RED_ANCHOR_KEY], red_generated_hex, blend_ratio_common)
    palette_hex_list.append(
        ensure_contrast(red_blended_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    green_saturation, green_value = apply_color_transform(config.GREEN, base_saturation, base_value)
    green_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(config.GREEN_HUE, green_saturation, green_value))
    green_blended_hex = blend_hex(catppuccin[config.GREEN_ANCHOR_KEY], green_generated_hex, blend_ratio_green)
    palette_hex_list.append(
        ensure_contrast(green_blended_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    yellow_saturation, yellow_value = apply_color_transform(config.YELLOW, base_saturation, base_value)
    yellow_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(config.YELLOW_HUE, yellow_saturation, yellow_value))
    yellow_blended_hex = blend_hex(catppuccin[config.YELLOW_ANCHOR_KEY], yellow_generated_hex, blend_ratio_yellow)
    palette_hex_list.append(
        ensure_contrast(yellow_blended_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    blue_saturation, blue_value = apply_color_transform(config.BLUE, base_saturation, base_value)
    blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(base_hue, blue_saturation, blue_value))
    palette_hex_list.append(
        ensure_contrast(blue_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    base_magenta_hue = wrap_hue(base_hue - config.MAGENTA_HUE_SHIFT)
    if honor_primary_hex and honor_hue is not None and honor_saturation is not None and honor_value is not None:
        magenta_saturation, magenta_value = apply_color_transform(
            config.MAGENTA_HONOR,
            honor_saturation,
            honor_value,
        )
        magenta_hue = honor_hue
    else:
        magenta_saturation, magenta_value = apply_color_transform(
            config.MAGENTA,
            base_saturation,
            base_value,
        )
        magenta_hue = base_magenta_hue
    magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_hue, magenta_saturation, magenta_value))
    palette_hex_list.append(
        ensure_contrast(magenta_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    cyan_hue = wrap_hue(base_hue + config.CYAN_HUE_SHIFT)
    if honor_primary_hex:
        cyan_hex = honor_primary_hex
    else:
        cyan_saturation, cyan_value = apply_color_transform(config.CYAN, base_saturation, base_value)
        cyan_hex = rgb_to_hex(*colorsys.hsv_to_rgb(cyan_hue, cyan_saturation, cyan_value))
    palette_hex_list.append(
        ensure_contrast(cyan_hex, resolved_background_hex, config.MIN_CONTRAST_MAIN, is_light_mode)
    )

    palette_hex_list.extend(config.NEUTRAL_INSERTS)

    bright_red_saturation, bright_red_value = apply_color_transform(config.BRIGHT_RED, base_saturation, base_value)
    bright_red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(config.RED_HUE, bright_red_saturation, bright_red_value))
    bright_red_hex = blend_hex(catppuccin[config.RED_ANCHOR_KEY], bright_red_generated_hex, blend_ratio_common)
    palette_hex_list.append(
        ensure_contrast(bright_red_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    bright_green_saturation, bright_green_value = apply_color_transform(
        config.BRIGHT_GREEN,
        base_saturation,
        base_value,
    )
    bright_green_generated_hex = rgb_to_hex(
        *colorsys.hsv_to_rgb(config.GREEN_HUE, bright_green_saturation, bright_green_value)
    )
    bright_green_hex = blend_hex(catppuccin[config.GREEN_ANCHOR_KEY], bright_green_generated_hex, blend_ratio_green)
    palette_hex_list.append(
        ensure_contrast(bright_green_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    bright_yellow_saturation, bright_yellow_value = apply_color_transform(
        config.BRIGHT_YELLOW,
        base_saturation,
        base_value,
    )
    bright_yellow_generated_hex = rgb_to_hex(
        *colorsys.hsv_to_rgb(config.YELLOW_HUE, bright_yellow_saturation, bright_yellow_value)
    )
    bright_yellow_hex = blend_hex(catppuccin[config.YELLOW_ANCHOR_KEY], bright_yellow_generated_hex, blend_ratio_yellow)
    palette_hex_list.append(
        ensure_contrast(bright_yellow_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    if honor_primary_hex and honor_hue is not None and honor_saturation is not None and honor_value is not None:
        bright_blue_saturation, bright_blue_value = apply_color_transform(
            config.BRIGHT_BLUE_HONOR,
            honor_saturation,
            honor_value,
        )
        bright_blue_hue = honor_hue
    else:
        bright_blue_saturation, bright_blue_value = apply_color_transform(
            config.BRIGHT_BLUE,
            base_saturation,
            base_value,
        )
        bright_blue_hue = base_hue
    bright_blue_hex = rgb_to_hex(
        *colorsys.hsv_to_rgb(bright_blue_hue, bright_blue_saturation, bright_blue_value)
    )
    palette_hex_list.append(
        ensure_contrast(bright_blue_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    bright_magenta_saturation, bright_magenta_value = apply_color_transform(
        config.BRIGHT_MAGENTA,
        base_saturation,
        base_value,
    )
    bright_magenta_hex = rgb_to_hex(
        *colorsys.hsv_to_rgb(base_magenta_hue, bright_magenta_saturation, bright_magenta_value)
    )
    palette_hex_list.append(
        ensure_contrast(bright_magenta_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    if is_light_mode:
        bright_cyan_hue = cyan_hue
    else:
        bright_cyan_hue = wrap_hue(base_hue + config.DARK_CYAN_ADDITIONAL_SHIFT)
    bright_cyan_saturation, bright_cyan_value = apply_color_transform(
        config.BRIGHT_CYAN,
        base_saturation,
        base_value,
    )
    bright_cyan_hex = rgb_to_hex(
        *colorsys.hsv_to_rgb(bright_cyan_hue, bright_cyan_saturation, bright_cyan_value)
    )
    palette_hex_list.append(
        ensure_contrast(bright_cyan_hex, resolved_background_hex, config.MIN_CONTRAST_BRIGHT, is_light_mode)
    )

    palette_hex_list.append(config.FINAL_CONTRAST_HEX)

    return palette_hex_list


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate 16-color palettes from base hues.")
    parser.add_argument("base_hex", nargs="?", help="Base hex color (e.g. #1f6feb).")
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--light", action="store_true", help="Force light mode palette.")
    mode_group.add_argument("--dark", action="store_true", help="Force dark mode palette.")
    parser.add_argument("--ghostty", action="store_true", help="Emit Ghostty configuration instead of Kitty.")
    parser.add_argument("--honor-primary", dest="honor_primary", metavar="HEX", help="Hex color to honor for magenta/cyan balance.")
    parser.add_argument("--background", metavar="HEX", help="Override background hex color.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    raw_args = argv if argv is not None else sys.argv[1:]
    args = parse_arguments(raw_args)

    base_hex_color = normalize_hex(args.base_hex)
    explicit_light = bool(args.light)
    explicit_dark = bool(args.dark)
    is_light_mode = explicit_light
    if explicit_dark:
        is_light_mode = False
    use_ghostty_output = bool(args.ghostty)
    honor_primary_hex = normalize_hex(args.honor_primary)
    background_hex = normalize_hex(args.background)

    wal_primary_hex, wal_primary_container_hex, wal_background_hex = read_wal_colors()

    if honor_primary_hex is None and wal_primary_hex:
        honor_primary_hex = wal_primary_hex

    if background_hex is None and wal_background_hex:
        background_hex = wal_background_hex

    if base_hex_color is None:
        if wal_primary_container_hex:
            base_hex_color = wal_primary_container_hex
        elif honor_primary_hex:
            base_hex_color = honor_primary_hex
        else:
            print(
                "Usage: dank16.py [<base_hex>] [--light] [--ghostty] [--honor-primary HEX] [--background HEX]",
                file=sys.stderr,
            )
            print(
                "Hint: No base color provided; also couldn't read primary_container from ~/.cache/wal/colors.json",
                file=sys.stderr,
            )
            return 1

    if base_hex_color is None:
        print("Error: base hex color could not be determined", file=sys.stderr)
        return 1

    grayscale_mode = False
    if is_grayscale_hex(base_hex_color):
        comparison_candidates = [candidate for candidate in (honor_primary_hex, wal_primary_hex) if candidate]
        grayscale_mode = all(is_grayscale_hex(candidate) for candidate in comparison_candidates) if comparison_candidates else True

    if not explicit_light and not explicit_dark and background_hex:
        is_light_mode = luminance(background_hex) > 0.75

    palette_hex_list = generate_palette(
        base_hex_color,
        is_light_mode,
        honor_primary_hex,
        background_hex,
        grayscale_mode,
    )

    if not use_ghostty_output:
        for color_index, hex_value in enumerate(palette_hex_list[:16]):
            print(f"color{color_index}   {hex_value}")
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
        for color_index, hex_value in enumerate(palette_hex_list[:16]):
            print(f"palette = {color_index}={hex_value}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
