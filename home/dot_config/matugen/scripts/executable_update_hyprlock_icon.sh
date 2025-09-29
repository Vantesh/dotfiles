#!/usr/bin/env bash

set -euo pipefail

readonly HYPRLOCK_PNG="$HOME/.cache/wal/icon.png"
readonly HYPRLOCK_SVG="$HOME/.cache/wal/icon.svg"

convert_icon() {
  local converter=()

  if command_exists magick; then
    converter=(magick -background none)
  elif command_exists convert; then
    converter=(convert -background none)
  else
    log "WARN" "ImageMagick (magick/convert) not found; cannot update Hyprlock icon"
    return 0
  fi

  if ! "${converter[@]}" "$HYPRLOCK_SVG" "$HYPRLOCK_PNG" >/dev/null 2>&1; then
    log "WARN" "Failed to refresh Hyprlock icon via ${converter[0]}"
  fi
}

main() {
  if [[ ! -f "$HYPRLOCK_SVG" ]]; then
    return 0
  fi

  if [[ -f "$HYPRLOCK_PNG" && "$HYPRLOCK_PNG" -nt "$HYPRLOCK_SVG" ]]; then
    return 0
  fi

  ensure_directory "$(dirname "$HYPRLOCK_PNG")"
  convert_icon
}

main "$@"
