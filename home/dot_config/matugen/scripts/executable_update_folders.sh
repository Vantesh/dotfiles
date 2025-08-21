#!/usr/bin/env bash
set -euo pipefail

# Define available Tela circle themes and approximate hex colors
declare -A TELA_COLORS=(
  [black]="#11111b"
  [blue]="#8caaee"
  [brown]="#fab387"
  [dracula]="#1e1e2e"
  [green]="#a6da95"
  [grey]="#939ab7"
  [manjaro]="#8bd5ca"
  [nord]="#838ba7"
  [orange]="#df8e1d"
  [pink]="#ea76cb"
  [purple]="#c6a0f6"
  [red]="#ed8796"
  [ubuntu]="#ef9f76"
  [yellow]="#df8e1d"
)

hex_to_rgb() {
  local hex=${1#"#"}
  echo "$((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))"
}

color_distance() {
  local r1 g1 b1 r2 g2 b2
  read -r r1 g1 b1 <<<"$(hex_to_rgb "$1")"
  read -r r2 g2 b2 <<<"$(hex_to_rgb "$2")"
  echo $(( (r1-r2)*(r1-r2) + (g1-g2)*(g1-g2) + (b1-b2)*(b1-b2) ))
}

closest_theme() {
  local target_hex=$1
  local best_theme=""
  local best_dist=999999999
  for theme in "${!TELA_COLORS[@]}"; do
    dist=$(color_distance "$target_hex" "${TELA_COLORS[$theme]}")
    if (( dist < best_dist )); then
      best_dist=$dist
      best_theme=$theme
    fi
  done
  echo "$best_theme"
}

# Read color from wal's papirus-folders file
if [[ -f "$HOME/.cache/wal/papirus-folders.txt" ]]; then
  requested_hex=$(<"$HOME/.cache/wal/folder-color.txt")
else
  echo "Error: $HOME/.cache/wal/papirus-folders.txt not found" >&2
  exit 1
fi

theme=$(closest_theme "$requested_hex")
variant="$MODE"

icon_name="Tela-circle-$theme-$variant"
echo "Info: Switching icon theme to: $icon_name"
gsettings set org.gnome.desktop.interface icon-theme "$icon_name"
