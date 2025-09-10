#!/usr/bin/env python3
import colorsys
import sys
import json
import os
from pathlib import Path

def hex_to_rgb(hex_color: str):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16)/255.0 for i in (0, 2, 4))

def rgb_to_hex(red: float, green: float, blue: float) -> str:
    red = max(0, min(1, red))
    green = max(0, min(1, green))
    blue = max(0, min(1, blue))
    return f"#{int(red*255):02x}{int(green*255):02x}{int(blue*255):02x}"


def blend_hex(hex_color_a: str, hex_color_b: str, blend_ratio: float) -> str:
    """Blend two hex colors. ratio=1.0 favors color_a, 0.0 favors color_b."""
    red_a, green_a, blue_a = hex_to_rgb(hex_color_a)
    red_b, green_b, blue_b = hex_to_rgb(hex_color_b)
    red_mix = red_a * blend_ratio + red_b * (1 - blend_ratio)
    green_mix = green_a * blend_ratio + green_b * (1 - blend_ratio)
    blue_mix = blue_a * blend_ratio + blue_b * (1 - blend_ratio)
    return rgb_to_hex(red_mix, green_mix, blue_mix)

def luminance(hex_color: str) -> float:
    red, green, blue = hex_to_rgb(hex_color)
    def srgb_to_linear(channel: float) -> float:
        return channel/12.92 if channel <= 0.03928 else ((channel + 0.055)/1.055) ** 2.4
    return 0.2126 * srgb_to_linear(red) + 0.7152 * srgb_to_linear(green) + 0.0722 * srgb_to_linear(blue)

def contrast_ratio(hex_foreground: str, hex_background: str) -> float:
    lum_foreground = luminance(hex_foreground)
    lum_background = luminance(hex_background)
    lighter = max(lum_foreground, lum_background)
    darker = min(lum_foreground, lum_background)
    return (lighter + 0.05) / (darker + 0.05)

def ensure_contrast(hex_color: str, hex_background: str, min_ratio: float = 4.5, is_light_mode: bool = False) -> str:
    current_ratio = contrast_ratio(hex_color, hex_background)
    if current_ratio >= min_ratio:
        return hex_color

    red, green, blue = hex_to_rgb(hex_color)
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)

    for step_index in range(1, 30):
        delta_value = step_index * 0.02

        if is_light_mode:
            new_value = max(0, value - delta_value)
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(hue, saturation, new_value))
            if contrast_ratio(candidate, hex_background) >= min_ratio:
                return candidate

            new_value = min(1, value + delta_value)
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(hue, saturation, new_value))
            if contrast_ratio(candidate, hex_background) >= min_ratio:
                return candidate
        else:
            new_value = min(1, value + delta_value)
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(hue, saturation, new_value))
            if contrast_ratio(candidate, hex_background) >= min_ratio:
                return candidate

            new_value = max(0, value - delta_value)
            candidate = rgb_to_hex(*colorsys.hsv_to_rgb(hue, saturation, new_value))
            if contrast_ratio(candidate, hex_background) >= min_ratio:
                return candidate

    return hex_color


def read_wal_colors(cache_path: Path):
    """Return (primary_hex, primary_container_hex, background_hex) from wal cache if present.
    Tries multiple schemas for robustness.
    """
    try:
        with cache_path.open() as file_handle:
            data = json.load(file_handle)
        # Direct keys (matugen-like)
        primary_hex = data.get('primary')
        primary_container_hex = data.get('primary_container')
        background_hex = data.get('background')
        # Pywal common schema fallbacks
        if background_hex is None:
            background_hex = (data.get('special') or {}).get('background')
        if (primary_hex is None) or (primary_container_hex is None):
            # Try deriving from palette if custom keys not present
            colors_obj = data.get('colors') or {}
            primary_hex = primary_hex or colors_obj.get('color4') or colors_obj.get('color12')  # blue-ish
            primary_container_hex = primary_container_hex or colors_obj.get('color5') or colors_obj.get('color13')  # magenta-ish
        return primary_hex, primary_container_hex, background_hex
    except Exception:
        return None, None, None

def read_ghostty_colors(cache_path: Path):
    """Return a dict of Ghostty color keys from cache JSON if present.
    Keys: background, foreground, cursor-color, cursor-text, selection-background, selection-foreground
    Accept both hyphenated and underscore variants for compatibility.
    """
    try:
        with cache_path.open() as fh:
            data = json.load(fh)
        def pick(*keys, default=None):
            for k in keys:
                v = data.get(k)
                if isinstance(v, str) and v:
                    return v if v.startswith('#') else f"#{v}"
            return default
        background = pick('background', ('special' in data and data['special'].get('background')) or None)
        foreground = pick('foreground', ('special' in data and data['special'].get('foreground')) or None)
        cursor_color = pick('cursor-color', 'cursor_color', 'cursor', default=foreground)
        cursor_text = pick('cursor-text', 'cursor_text', default=foreground)
        sel_bg = pick('selection-background', 'selection_background', default=background)
        sel_fg = pick('selection-foreground', 'selection_foreground', default=foreground)
        result = {}
        if background: result['background'] = background
        if foreground: result['foreground'] = foreground
        if cursor_color: result['cursor-color'] = cursor_color
        if cursor_text: result['cursor-text'] = cursor_text
        if sel_bg: result['selection-background'] = sel_bg
        if sel_fg: result['selection-foreground'] = sel_fg
        return result
    except Exception:
        return {}

def generate_palette(base_hex_color: str, is_light_mode: bool = False, honor_primary_hex: str | None = None, background_hex: str | None = None):
    base_red, base_green, base_blue = hex_to_rgb(base_hex_color)
    base_hue, base_saturation, base_value = colorsys.rgb_to_hsv(base_red, base_green, base_blue)

    palette_hex_list = []

    # Resolve background first
    if background_hex:
        resolved_background_hex = background_hex
    else:
        resolved_background_hex = "#f8f8f8" if is_light_mode else "#1a1a1a"
    palette_hex_list.append(resolved_background_hex)

    # Catppuccin anchors for blending
    catppuccin = {
        'red_light': '#d20f39', 'green_light': '#40a02b', 'yellow_light': '#df8e1d',
        'red_dark': '#f38ba8', 'green_dark': '#8bd5a1', 'yellow_dark': '#dba63a'
    }

    # Blend ratios inspired by v1
    blend_ratio_common = 0.6 if is_light_mode else 0.5
    blend_ratio_green_dark = 0.75 if not is_light_mode else blend_ratio_common
    blend_ratio_yellow_dark = 0.35 if not is_light_mode else blend_ratio_common

    # Red
    red_hue = 0.0
    if is_light_mode:
        red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(red_hue, 0.75, 0.85))
        red_blended_hex = blend_hex(catppuccin['red_light'], red_generated_hex, blend_ratio_common)
    else:
        red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(red_hue, 0.6, 0.8))
        red_blended_hex = blend_hex(catppuccin['red_dark'], red_generated_hex, blend_ratio_common)
    palette_hex_list.append(ensure_contrast(red_blended_hex, resolved_background_hex, 4.5, is_light_mode))

    # Green
    green_hue = 0.33
    if is_light_mode:
        green_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(green_hue, max(base_saturation * 0.9, 0.75), base_value * 0.6))
        green_blended_hex = blend_hex(catppuccin['green_light'], green_generated_hex, blend_ratio_common)
    else:
        green_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(green_hue, max(base_saturation * 0.65, 0.5), base_value * 0.9))
        green_blended_hex = blend_hex(catppuccin['green_dark'], green_generated_hex, blend_ratio_green_dark)
    palette_hex_list.append(ensure_contrast(green_blended_hex, resolved_background_hex, 4.5, is_light_mode))

    # Yellow
    yellow_hue = 0.08
    if is_light_mode:
        yellow_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_hue, max(base_saturation * 0.85, 0.7), base_value * 0.7))
        yellow_blended_hex = blend_hex(catppuccin['yellow_light'], yellow_generated_hex, blend_ratio_common)
    else:
        yellow_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_hue, max(base_saturation * 0.5, 0.45), base_value * 1.4))
        yellow_blended_hex = blend_hex(catppuccin['yellow_dark'], yellow_generated_hex, blend_ratio_yellow_dark)
    palette_hex_list.append(ensure_contrast(yellow_blended_hex, resolved_background_hex, 4.5, is_light_mode))

    # Blue (derived from base)
    if is_light_mode:
        blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(base_hue, max(base_saturation * 0.9, 0.7), base_value * 1.1))
    else:
        blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(base_hue, max(base_saturation * 0.8, 0.6), min(base_value * 1.6, 1.0)))
    palette_hex_list.append(ensure_contrast(blue_hex, resolved_background_hex, 4.5, is_light_mode))

    # Magenta (offset from base or honor primary)
    magenta_hue = base_hue - 0.03 if base_hue >= 0.03 else base_hue + 0.97
    if honor_primary_hex:
        honor_red, honor_green, honor_blue = hex_to_rgb(honor_primary_hex)
        honor_hue, honor_saturation, honor_value = colorsys.rgb_to_hsv(honor_red, honor_green, honor_blue)
        if is_light_mode:
            magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(honor_hue, max(honor_saturation * 0.9, 0.7), honor_value * 0.85))
        else:
            magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(honor_hue, honor_saturation * 0.8, honor_value * 0.75))
    elif is_light_mode:
        magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_hue, max(base_saturation * 0.75, 0.6), base_value * 0.9))
    else:
        magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_hue, max(base_saturation * 0.7, 0.6), base_value * 0.85))
    palette_hex_list.append(ensure_contrast(magenta_hex, resolved_background_hex, 4.5, is_light_mode))

    # Cyan (offset from base or honor primary)
    cyan_hue = base_hue + 0.08
    if honor_primary_hex:
        cyan_hex = honor_primary_hex
    elif is_light_mode:
        cyan_hex = rgb_to_hex(*colorsys.hsv_to_rgb(cyan_hue, max(base_saturation * 0.8, 0.65), base_value * 1.05))
    else:
        cyan_hex = rgb_to_hex(*colorsys.hsv_to_rgb(cyan_hue, max(base_saturation * 0.6, 0.5), min(base_value * 1.25, 0.85)))
    palette_hex_list.append(ensure_contrast(cyan_hex, resolved_background_hex, 4.5, is_light_mode))

    # Neutral grays
    if is_light_mode:
        palette_hex_list.append("#2e2e2e")
        palette_hex_list.append("#4a4a4a")
    else:
        palette_hex_list.append("#abb2bf")
        palette_hex_list.append("#5c6370")

    # Brights (with Catppuccin blending for R/G/Y)
    if is_light_mode:
        bright_red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(red_hue, 0.6, 0.9))
        bright_red_hex = blend_hex(catppuccin['red_light'], bright_red_generated_hex, blend_ratio_common)
        palette_hex_list.append(ensure_contrast(bright_red_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_green_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(green_hue, max(base_saturation * 0.8, 0.7), base_value * 0.65))
        bright_green_hex = blend_hex(catppuccin['green_light'], bright_green_generated_hex, blend_ratio_common)
        palette_hex_list.append(ensure_contrast(bright_green_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_yellow_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_hue, max(base_saturation * 0.75, 0.65), base_value * 0.75))
        bright_yellow_hex = blend_hex(catppuccin['yellow_light'], bright_yellow_generated_hex, blend_ratio_common)
        palette_hex_list.append(ensure_contrast(bright_yellow_hex, resolved_background_hex, 3.0, is_light_mode))

        if honor_primary_hex:
            bright_blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(honor_hue, min(honor_saturation * 1.1, 1.0), min(honor_value * 1.2, 1.0)))
        else:
            bright_blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(base_hue, max(base_saturation * 0.8, 0.7), min(base_value * 1.3, 1.0)))
        palette_hex_list.append(ensure_contrast(bright_blue_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_hue, max(base_saturation * 0.9, 0.75), min(base_value * 1.25, 1.0)))
        palette_hex_list.append(ensure_contrast(bright_magenta_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_cyan_hex = rgb_to_hex(*colorsys.hsv_to_rgb(cyan_hue, max(base_saturation * 0.75, 0.65), min(base_value * 1.25, 1.0)))
        palette_hex_list.append(ensure_contrast(bright_cyan_hex, resolved_background_hex, 3.0, is_light_mode))
    else:
        bright_red_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(red_hue, 0.45, min(1.0, 0.9)))
        bright_red_hex = blend_hex(catppuccin['red_dark'], bright_red_generated_hex, blend_ratio_common)
        palette_hex_list.append(ensure_contrast(bright_red_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_green_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(green_hue, max(base_saturation * 0.5, 0.4), min(base_value * 1.5, 0.9)))
        bright_green_hex = blend_hex(catppuccin['green_dark'], bright_green_generated_hex, blend_ratio_green_dark)
        palette_hex_list.append(ensure_contrast(bright_green_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_yellow_generated_hex = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_hue, max(base_saturation * 0.4, 0.35), min(base_value * 1.6, 0.95)))
        bright_yellow_hex = blend_hex(catppuccin['yellow_dark'], bright_yellow_generated_hex, blend_ratio_yellow_dark)
        palette_hex_list.append(ensure_contrast(bright_yellow_hex, resolved_background_hex, 3.0, is_light_mode))

        if honor_primary_hex:
            bright_blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(honor_hue, min(honor_saturation * 1.2, 1.0), min(honor_value * 1.1, 1.0)))
        else:
            bright_blue_hex = rgb_to_hex(*colorsys.hsv_to_rgb(base_hue, max(base_saturation * 0.6, 0.5), min(base_value * 1.5, 0.9)))
        palette_hex_list.append(ensure_contrast(bright_blue_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_magenta_hex = rgb_to_hex(*colorsys.hsv_to_rgb(magenta_hue, max(base_saturation * 0.7, 0.6), min(base_value * 1.3, 0.9)))
        palette_hex_list.append(ensure_contrast(bright_magenta_hex, resolved_background_hex, 3.0, is_light_mode))

        bright_cyan_hex = rgb_to_hex(*colorsys.hsv_to_rgb((base_hue + 0.02) if base_hue + 0.02 <= 1.0 else base_hue + 0.02 - 1.0, max(base_saturation * 0.6, 0.5), min(base_value * 1.2, 0.85)))
        palette_hex_list.append(ensure_contrast(bright_cyan_hex, resolved_background_hex, 3.0, is_light_mode))

    # Foreground
    palette_hex_list.append("#1a1a1a" if is_light_mode else "#ffffff")

    return palette_hex_list

if __name__ == "__main__":
    # Parse CLI
    cli_arguments = sys.argv[1:]

    # Optional base color positional argument
    base_hex_color = None
    for argument in cli_arguments:
        if not argument.startswith('-'):
            base_hex_color = argument if argument.startswith('#') else f"#{argument}"
            break

    is_light_mode = "--light" in cli_arguments
    use_ghostty_output = "--ghostty" in cli_arguments

    honor_primary_hex = None
    if "--honor-primary" in cli_arguments:
        try:
            honor_index = cli_arguments.index("--honor-primary")
            honor_primary_hex = cli_arguments[honor_index + 1]
            if not honor_primary_hex.startswith('#'):
                honor_primary_hex = '#' + honor_primary_hex
        except (ValueError, IndexError):
            print("Error: --honor-primary requires a hex color", file=sys.stderr)
            sys.exit(1)

    background_hex = None
    if "--background" in cli_arguments:
        try:
            bg_index = cli_arguments.index("--background")
            background_hex = cli_arguments[bg_index + 1]
            if not background_hex.startswith('#'):
                background_hex = '#' + background_hex
        except (ValueError, IndexError):
            print("Error: --background requires a hex color", file=sys.stderr)
            sys.exit(1)

    # Load wal colors if needed
    cache_path = Path(os.path.expanduser('~/.cache/wal/colors.json'))
    wal_primary_hex, wal_primary_container_hex, wal_background_hex = read_wal_colors(cache_path)

    if honor_primary_hex is None and wal_primary_hex:
        honor_primary_hex = wal_primary_hex if wal_primary_hex.startswith('#') else f"#{wal_primary_hex}"

    if background_hex is None and wal_background_hex:
        background_hex = wal_background_hex if wal_background_hex.startswith('#') else f"#{wal_background_hex}"

    if base_hex_color is None:
        if wal_primary_container_hex:
            wal_pc = wal_primary_container_hex if wal_primary_container_hex.startswith('#') else f"#{wal_primary_container_hex}"
            base_hex_color = wal_pc
        elif honor_primary_hex:
            base_hex_color = honor_primary_hex
        else:
            print("Usage: dank16.py [<base_hex>] [--light] [--ghostty] [--honor-primary HEX] [--background HEX]", file=sys.stderr)
            print("Hint: No base color provided; also couldn't read primary_container from ~/.cache/wal/colors.json", file=sys.stderr)
            sys.exit(1)

    # If light/dark not explicit and we have background, infer from luminance
    if "--light" not in cli_arguments and background_hex:
        is_light_mode = luminance(background_hex) > 0.75  # bright backgrounds imply light mode

    palette_hex_list = generate_palette(base_hex_color, is_light_mode, honor_primary_hex, background_hex)

    if not use_ghostty_output:
        # Default: Kitty format color0..15
        for color_index in range(min(16, len(palette_hex_list))):
            print(f"color{color_index}   {palette_hex_list[color_index]}")
    else:
        # If available, emit Ghostty extra keys from cache
        ghostty_extras = read_ghostty_colors(cache_path)
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
        for color_index in range(min(16, len(palette_hex_list))):
            print(f"palette = {color_index}={palette_hex_list[color_index]}")
