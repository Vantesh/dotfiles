#!/usr/bin/env python3
import colorsys
import sys
import os
import json
from pathlib import Path


def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16)/255.0 for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    r = max(0, min(1, r))
    g = max(0, min(1, g))
    b = max(0, min(1, b))
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"


def blend_hex(hex_a, hex_b, ratio: float):
    ar, ag, ab = hex_to_rgb(hex_a)
    br, bg, bb = hex_to_rgb(hex_b)
    r = ar * ratio + br * (1 - ratio)
    g = ag * ratio + bg * (1 - ratio)
    b = ab * ratio + bb * (1 - ratio)
    return rgb_to_hex(r, g, b)


def generate_palette(base_color, is_light=False, honor_primary=None):
    r, g, b = hex_to_rgb(base_color)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)

    palette = []

    if is_light:
        palette.append("#f8f8f8")
    else:
        palette.append("#1a1a1a")

    def luminance(hex_color):
        rr, gg, bb = hex_to_rgb(hex_color)
        def channel(c):
            return c/12.92 if c <= 0.03928 else ((c+0.055)/1.055) ** 2.4
        return 0.2126 * channel(rr) + 0.7152 * channel(gg) + 0.0722 * channel(bb)

    def contrast_ratio(hex_a, hex_b):
        la = luminance(hex_a)
        lb = luminance(hex_b)
        hi = max(la, lb)
        lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)

    def ensure_contrast(hex_color, bg_hex, min_ratio=4.5):
        """Adjust value (v) in HSV to reach at least min_ratio against bg_hex.
        Keeps hue and saturation, only nudges brightness. Returns hex string."""
        cr = contrast_ratio(hex_color, bg_hex)
        if cr >= min_ratio:
            return hex_color
        # try darkening then lightening, small steps
        r0, g0, b0 = hex_to_rgb(hex_color)
        hh, ss, vv = colorsys.rgb_to_hsv(r0, g0, b0)
        # try up to 20 steps
        for step in range(1, 21):
            # darken
            nv = max(0.0, vv - step * 0.03)
            cand = rgb_to_hex(*colorsys.hsv_to_rgb(hh, ss, nv))
            if contrast_ratio(cand, bg_hex) >= min_ratio:
                return cand
            # lighten
            nv = min(1.0, vv + step * 0.03)
            cand = rgb_to_hex(*colorsys.hsv_to_rgb(hh, ss, nv))
            if contrast_ratio(cand, bg_hex) >= min_ratio:
                return cand
        # fallback: return original if no sufficient contrast found
        return hex_color

    # catppuccin colors, idk i love them :)
    cat = {'red_light': '#d20f39', 'green_light': '#40a02b', 'yellow_light': '#df8e1d', 'red_dark': '#f38ba8', 'green_dark': '#8bd5a1', 'yellow_dark': '#dba63a'}

    blend_ratio = 0.6 if is_light else 0.5
    dark_yellow_blend = 0.35 if not is_light else blend_ratio
    dark_green_blend = 0.75 if not is_light else blend_ratio

    red_h = 0.0
    if is_light:
        gen_red = rgb_to_hex(*colorsys.hsv_to_rgb(red_h, 0.75, 0.85))
        palette.append(ensure_contrast(blend_hex(cat['red_light'], gen_red, blend_ratio), "#f8f8f8"))
    else:
        gen_red = rgb_to_hex(*colorsys.hsv_to_rgb(red_h, 0.6, 0.8))
        palette.append(ensure_contrast(blend_hex(cat['red_dark'], gen_red, blend_ratio), "#1a1a1a"))

    green_h = 0.33
    if is_light:
        gen_green = rgb_to_hex(*colorsys.hsv_to_rgb(green_h, max(s * 0.8, 0.65), v * 0.9))
        palette.append(ensure_contrast(blend_hex(cat['green_light'], gen_green, blend_ratio), "#f8f8f8"))
    else:
        gen_green = rgb_to_hex(*colorsys.hsv_to_rgb(green_h, max(s * 0.65, 0.5), v * 0.9))
        palette.append(ensure_contrast(blend_hex(cat['green_dark'], gen_green, dark_green_blend), "#1a1a1a"))

    yellow_h = 0.16
    if is_light:
        gen_yellow = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_h, max(s * 0.7, 0.55), v * 1.2))
        palette.append(ensure_contrast(blend_hex(cat['yellow_light'], gen_yellow, blend_ratio), "#f8f8f8"))
    else:
        gen_yellow = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_h, max(s * 0.5, 0.45), v * 1.4))
        palette.append(ensure_contrast(blend_hex(cat['yellow_dark'], gen_yellow, dark_yellow_blend), "#1a1a1a"))

    if is_light:
        palette.append(ensure_contrast(rgb_to_hex(*colorsys.hsv_to_rgb(h, max(s * 0.9, 0.7), v * 1.1)), "#f8f8f8"))
    else:
        palette.append(ensure_contrast(rgb_to_hex(*colorsys.hsv_to_rgb(h, max(s * 0.8, 0.6), min(v * 1.6, 1.0))), "#1a1a1a"))

    mag_h = h - 0.03 if h >= 0.03 else h + 0.97
    if honor_primary:
        hr, hg, hb = hex_to_rgb(honor_primary)
        hh, hs, hv = colorsys.rgb_to_hsv(hr, hg, hb)
        if is_light:
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(hh, max(hs * 0.9, 0.7), hv * 0.85)))
        else:
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(hh, hs * 0.8, hv * 0.75)))
    elif is_light:
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(mag_h, max(s * 0.75, 0.6), v * 0.9)))
    else:
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(mag_h, max(s * 0.7, 0.6), v * 0.85)))

    cyan_h = h + 0.08
    if honor_primary:
        if is_light:
            palette.append(honor_primary)
        else:
            palette.append(honor_primary)
    elif is_light:
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(cyan_h, max(s * 0.8, 0.65), v * 1.05)))
    else:
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(cyan_h, max(s * 0.6, 0.5), min(v * 1.25, 0.85))))

    if is_light:
        palette.append("#2e2e2e")
        palette.append("#4a4a4a")
    else:
        palette.append("#abb2bf")
        palette.append("#5c6370")

    if is_light:
        gen_red2 = rgb_to_hex(*colorsys.hsv_to_rgb(red_h, 0.6, 0.9))
        palette.append(blend_hex(cat['red_light'], gen_red2, blend_ratio))
        gen_green2 = rgb_to_hex(*colorsys.hsv_to_rgb(green_h, max(s * 0.7, 0.6), v * 1.25))
        palette.append(blend_hex(cat['green_light'], gen_green2, blend_ratio))
        gen_yellow2 = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_h, max(s * 0.6, 0.5), v * 1.35))
        palette.append(blend_hex(cat['yellow_light'], gen_yellow2, blend_ratio))
        if honor_primary:
            hr, hg, hb = hex_to_rgb(honor_primary)
            hh, hs, hv = colorsys.rgb_to_hsv(hr, hg, hb)
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(hh, min(hs * 1.1, 1.0), min(hv * 1.2, 1.0))))
        else:
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(h, max(s * 0.8, 0.7), min(v * 1.3, 1.0))))
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(mag_h, max(s * 0.9, 0.75), min(v * 1.25, 1.0))))
        palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(cyan_h, max(s * 0.75, 0.65), min(v * 1.25, 1.0))))
    else:
        gen_red2 = rgb_to_hex(*colorsys.hsv_to_rgb(red_h, 0.45, min(1.0, 0.9)))
        palette.append(blend_hex(cat['red_dark'], gen_red2, blend_ratio))
        gen_green2 = rgb_to_hex(*colorsys.hsv_to_rgb(green_h, max(s * 0.5, 0.4), min(v * 1.5, 0.9)))
        palette.append(blend_hex(cat['green_dark'], gen_green2, blend_ratio))
        gen_yellow2 = rgb_to_hex(*colorsys.hsv_to_rgb(yellow_h, max(s * 0.4, 0.35), min(v * 1.6, 0.95)))
        palette.append(blend_hex(cat['yellow_dark'], gen_yellow2, blend_ratio))
        if honor_primary:
            hr, hg, hb = hex_to_rgb(honor_primary)
            hh, hs, hv = colorsys.rgb_to_hsv(hr, hg, hb)
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(hh, min(hs * 1.2, 1.0), min(hv * 1.1, 1.0))))
        else:
            palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(h, max(s * 0.6, 0.5), min(v * 1.5, 0.9))))
    palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(mag_h, max(s * 0.7, 0.6), min(v * 1.3, 0.9))))
    palette.append(rgb_to_hex(*colorsys.hsv_to_rgb(h + 0.02 if h + 0.02 <= 1.0 else h + 0.02 - 1.0, max(s * 0.6, 0.5), min(v * 1.2, 0.85))))

    if is_light:
        palette.append("#1a1a1a")
    else:
        palette.append("#ffffff")

    return palette


def read_wal_colors(path: Path):
    try:
        with path.open() as f:
            data = json.load(f)
            primary = data.get('primary')
            primary_container = data.get('primary_container')
            return primary, primary_container
    except Exception:
        return None, None


def main():
    args = sys.argv[1:]
    is_light = '--light' in args

    honor_primary = None
    if '--honor-primary' in args:
        try:
            i = args.index('--honor-primary')
            honor_primary = args[i+1]
            if not honor_primary.startswith('#'):
                honor_primary = '#' + honor_primary
        except Exception:
            honor_primary = None

    base = None
    for a in args:
        if not a.startswith('-'):
            base = a
            break

    if base:
        if not base.startswith('#'):
            base = '#' + base
    else:
        cache = Path(os.path.expanduser('~/.cache/wal/colors.json'))
        p, pc = read_wal_colors(cache)
        if pc:
            base = pc if pc.startswith('#') else ('#' + pc)
        elif p:
            base = p if p.startswith('#') else ('#' + p)
        else:
            print('Error: no base color provided and wal cache not found', file=sys.stderr)
            sys.exit(1)

    if not honor_primary:
        cache = Path(os.path.expanduser('~/.cache/wal/colors.json'))
        p, pc = read_wal_colors(cache)
        if p:
            honor_primary = p if p.startswith('#') else ('#' + p)

    colors = generate_palette(base, is_light=is_light, honor_primary=honor_primary)

    kitty_colors = [(f"color{i}", colors[i]) for i in range(min(16, len(colors)))]
    for name, color in kitty_colors:
        print(f"{name}   {color}")


if __name__ == '__main__':
    main()
