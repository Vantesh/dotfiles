#!/usr/bin/env bash
# update_hyprlock_icon.sh - Convert Hyprlock SVG icon to PNG format
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

LAST_ERROR=""
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"

log() {
  local level="${1:-}"
  shift || true
  local message="$*"
  case "${level^^}" in
  INFO) printf '  %bINFO%b  %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message" >&2 ;;
  WARN) printf '  %bWARN%b  %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message" >&2 ;;
  ERROR) printf '  %bERROR%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" >&2 ;;
  SKIP) printf '  %bSKIP%b  %s\n' "\033[1;35m" "$COLOR_RESET" "$message" >&2 ;;
  *) printf '%s\n' "$message" >&2 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

ensure_directory() {
  LAST_ERROR=""
  local path="$1"
  if ! mkdir -p "$path" 2>/dev/null; then
    LAST_ERROR="Failed to create directory: $path"
    return 1
  fi
  return 0
}

readonly HYPRLOCK_PNG="$HOME/.cache/wal/icon.png"
readonly HYPRLOCK_SVG="$HOME/.cache/wal/icon.svg"

# convert_icon converts SVG icon to PNG using ImageMagick
# Returns: 0 on success, 1 if ImageMagick unavailable
convert_icon() {
  local -a converter=()

  if command_exists magick; then
    converter=(magick -background none)
  elif command_exists convert; then
    converter=(convert -background none)
  else
    log WARN "ImageMagick (magick/convert) not found; cannot update Hyprlock icon"
    return 1
  fi

  if ! "${converter[@]}" "$HYPRLOCK_SVG" "$HYPRLOCK_PNG" >/dev/null 2>&1; then
    log WARN "Failed to refresh Hyprlock icon via ${converter[0]}"
    return 1
  fi

  log INFO "Converted Hyprlock icon to PNG"
  return 0
}

main() {
  if [[ ! -f "$HYPRLOCK_SVG" ]]; then
    return 0
  fi

  if [[ -f "$HYPRLOCK_PNG" && "$HYPRLOCK_PNG" -nt "$HYPRLOCK_SVG" ]]; then
    log SKIP "Hyprlock PNG is up to date"
    return 0
  fi

  if ! ensure_directory "$(dirname "$HYPRLOCK_PNG")"; then
    log ERROR "Failed to create cache directory: $LAST_ERROR"
    return 1
  fi

  convert_icon || return 1

  return 0
}

main "$@"
