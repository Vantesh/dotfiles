#!/usr/bin/env bash

set -euo pipefail

readonly HYPRLOCK_PNG="$HOME/.config/hypr/hyprlock/icon.png"
readonly HYPRLOCK_SVG="$HOME/.cache/wal/icon.svg"

# Hyprlock icon
if [[ -f "$HYPRLOCK_SVG" ]]; then
  if command -v magick &>/dev/null; then
    magick -background none "$HYPRLOCK_SVG" "$HYPRLOCK_PNG" &>/dev/null &
  elif command -v convert &>/dev/null; then
    convert -background none "$HYPRLOCK_SVG" "$HYPRLOCK_PNG" &>/dev/null &
  else
    log_error "ImageMagick not found, skipping hyprlock icon"
  fi
fi
