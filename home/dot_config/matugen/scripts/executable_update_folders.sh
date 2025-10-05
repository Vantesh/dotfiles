#!/usr/bin/env bash
set -euo pipefail

readonly FOLDER_HEX_FILE="$HOME/.cache/wal/folder-color.txt"
readonly CACHE_DIR="$HOME/.cache/wal"
readonly CACHE_NEAREST_FILE="$CACHE_DIR/folder-color.nearest"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

read_requested_hex() {
  if [[ ! -f "$FOLDER_HEX_FILE" ]]; then
    log "ERROR" "Requested folder color not found: $FOLDER_HEX_FILE"
    return 1
  fi

  tr -d '[:space:]' <"$FOLDER_HEX_FILE"
}

compute_nearest_tela_color() {
  local hex="$1"

  require_command python3 || return 1
  local nearest
  if ! nearest=$(python3 "$SCRIPT_DIR/nearest_tela_color.py" "$hex" "$CACHE_NEAREST_FILE"); then
    log "ERROR" "Failed to resolve nearest Tela color"
    return 1
  fi

  nearest=${nearest//$'\n'/}
  if [[ -z "$nearest" ]]; then
    log "WARN" "Nearest Tela color detection returned empty result"
  fi

  printf '%s\n' "$nearest"
}

resolve_icon_variant() {
  local nearest_color="$1"
  local variant="${MODE:-dark}"

  if [[ -z "$nearest_color" ]]; then
    log "WARN" "Nearest Tela color unavailable; defaulting to 'dark'"
    nearest_color="dark"
  fi

  if [[ "$variant" != "light" && "$variant" != "dark" ]]; then
    log "WARN" "Invalid MODE='$variant'; defaulting to dark"
    variant="dark"
  fi

  if [[ "$nearest_color" == "dark" ]]; then
    if [[ "$variant" == "dark" ]]; then
      printf 'Tela-dark\n'
    else
      printf 'Tela\n'
    fi
    return
  fi

  printf 'Tela-%s-%s\n' "$nearest_color" "$variant"
}

apply_icon_theme() {
  local icon_name="$1"
  set_gsetting_if_needed org.gnome.desktop.interface icon-theme "$icon_name" "icon-theme"
}

update_qt_icon_theme() {
  local icon_name="$1"
  local configs=(
    "$HOME/.config/qt5ct/qt5ct.conf"
    "$HOME/.config/qt6ct/qt6ct.conf"
  )

  for conf in "${configs[@]}"; do
    if [[ ! -f "$conf" ]]; then
      continue
    fi

    local current
    current=$(grep -E '^icon_theme[[:space:]]*=' "$conf" | tail -n1 | cut -d'=' -f2- | tr -d '[:space:]' || true)
    if [[ "$current" == "$icon_name" ]]; then
      continue
    fi

    if ! set_config_value "$conf" "icon_theme" '=' "$icon_name" compact; then
      log "WARN" "Failed to update Qt icon theme in $conf"
    fi
  done
}

main() {
  local requested_hex
  requested_hex=$(read_requested_hex) || return 1

  local nearest_color
  nearest_color=$(compute_nearest_tela_color "$requested_hex") || return 1

  local icon_name
  icon_name=$(resolve_icon_variant "$nearest_color")

  apply_icon_theme "$icon_name"
  update_qt_icon_theme "$icon_name"
}

main "$@"
