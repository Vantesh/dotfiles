#!/usr/bin/env bash

set -euo pipefail

log_error() { echo "Error: $*" >&2; }
log_info() { echo "Info: $*"; }

# Map of Papirus folder color names to hex values for nearest-match selection
# Keep in sync with walset's previous mapping
declare -A FOLDER_COLORS=(
  ["blue"]="#89B4FA" ["grey"]="#878688" ["green"]="#84A756" ["adwaita"]="#B4BEFE"
  ["carmine"]="#AC0406" ["magenta"]="#CBA6F7" ["orange"]="#E58E3B" ["pink"]="#F5C2E7"
  ["red"]="#F38BA8" ["breeze"]="#89DCEB" ["teal"]="#94E2D5" ["yellow"]="#F9E2AF"
  ["violet"]="#7653B4" ["cyan"]="#04ADC4" ["nordic"]="#7895B3" ["palebrown"]="#D1BFAE"
  ["deeporange"]="#DB633A" ["brown"]="#AD8B6C" ["paleorange"]="#E8C289" ["darkcyan"]="#45ABB7"
  ["black"]="#4F4F4F" ["bluegrey"]="#607D8B"
)

if ! command -v papirus-folders &>/dev/null; then
  log_info "papirus-folders not found, skipping folder theming"
  exit 0
fi

cache_file="$HOME/.cache/wal/papirus-folders.txt"
if [[ ! -f "$cache_file" ]]; then
  log_error "Color cache file not found: $cache_file"
  exit 1
fi

# read hex and normalize
read -r target_hex <"$cache_file" || { log_error "Failed to read color from cache file"; exit 1; }

# strip leading # and uppercase
target_hex="${target_hex#\#}"
target_hex="${target_hex^^}"

if [[ ! "$target_hex" =~ ^[0-9A-F]{6}$ ]]; then
  log_error "Invalid hex color format in cache file: $target_hex"
  exit 1
fi

r1=$(( 0x${target_hex:0:2} ))
g1=$(( 0x${target_hex:2:2} ))
b1=$(( 0x${target_hex:4:2} ))

min_distance=1000000
closest_color=""

for name in "${!FOLDER_COLORS[@]}"; do
  color_hex="${FOLDER_COLORS[$name]#\#}"
  r2=$(( 0x${color_hex:0:2} ))
  g2=$(( 0x${color_hex:2:2} ))
  b2=$(( 0x${color_hex:4:2} ))
  distance=$(( (r1-r2)*(r1-r2) + (g1-g2)*(g1-g2) + (b1-b2)*(b1-b2) ))
  if (( distance < min_distance )); then
    min_distance=$distance
    closest_color=$name
  fi
done

if [[ -n "$closest_color" ]]; then
  if ! papirus-folders -C "$closest_color" -t Papirus-Dark &>/dev/null; then
    log_error "Failed to apply folder color: $closest_color"
    exit 1
  fi
else
  log_error "No matching folder color found"
  exit 1
fi
