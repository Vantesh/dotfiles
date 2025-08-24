#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Step 1: Read requested hex color from wal's folder-color.txt
# =============================================================================
if [[ -f "$HOME/.cache/wal/folder-color.txt" ]]; then
  requested_hex=$(<"$HOME/.cache/wal/folder-color.txt")
else
  echo "Error: $HOME/.cache/wal/folder-color.txt not found" >&2
  exit 1
fi

# =============================================================================
# Step 2: Call Python for the complex color math
# =============================================================================
nearest_color=$(python3 -c "
import sys, colorsys, math

hex_color = sys.argv[1]

# Tela color definitions (name, hex)
tela_colors = {
    'nord': '#4d576a',
    'grey': '#bdbdbd',
    'purple': '#7e57c2',
    'brown': '#795548',
    'dark': '#5294e2',
    'red': '#ef5350',
    'manjaro': '#16a085',
    'orange': '#e18908',
    'blue': '#5677fc',
    'pink': '#f06292',
    'ubuntu': '#fb8441',
    'green': '#66bb6a',
    'dracula': '#44475a',
    'yellow': '#ffca28',
    'black': '#11111b',
}

def hex_to_hsl(hex_color):
    hex_color = hex_color.lstrip('#')
    r, g, b = tuple(int(hex_color[i:i+2], 16)/255.0 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return (h*360, s, l)

def color_distance(hsl1, hsl2):
    # Weighted HSL distance with hue priority
    dh = min(abs(hsl1[0] - hsl2[0]), 360 - abs(hsl1[0] - hsl2[0])) / 180.0
    ds = abs(hsl1[1] - hsl2[1])
    dl = abs(hsl1[2] - hsl2[2])
    return 0.7*dh + 0.2*ds + 0.1*dl

input_hsl = hex_to_hsl(hex_color)
min_distance = float('inf')
nearest_color = ''

for name, tela_hex in tela_colors.items():
    tela_hsl = hex_to_hsl(tela_hex)
    distance = color_distance(input_hsl, tela_hsl)
    if distance < min_distance:
        min_distance = distance
        nearest_color = name

print(nearest_color)
" "$requested_hex")

# =============================================================================
# Step 3: Switch to matched Tela circle theme
# =============================================================================
variant="${MODE:-dark}" # default to dark if unset

if [[ "$nearest_color" == "dark" ]]; then
  if [[ "$variant" == "dark" ]]; then
    icon_name="Tela-circle-dark"
  else
    icon_name="Tela-circle"
  fi
else
  icon_name="Tela-circle-$nearest_color-$variant"
fi

echo "Info: Switching icon theme to: $icon_name"
gsettings set org.gnome.desktop.interface icon-theme "$icon_name"

# =============================================================================
# Step 4: Also set Qt icon theme
# =============================================================================
qt5ct_conf="$HOME/.config/qt5ct/qt5ct.conf"
qt6ct_conf="$HOME/.config/qt6ct/qt6ct.conf"

for conf in "$qt5ct_conf" "$qt6ct_conf"; do
  if [[ -f "$conf" ]]; then
    if grep -q '^icon_theme=' "$conf"; then
      sed -i "s/^icon_theme=.*/icon_theme=$icon_name/" "$conf"
    else
      echo "icon_theme=$icon_name" >>"$conf"
    fi
    echo "Info: Updated Qt icon theme in $conf"
  fi
done
