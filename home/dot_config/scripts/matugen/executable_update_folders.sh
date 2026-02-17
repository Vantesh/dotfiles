#!/usr/bin/env bash
# update_folders.sh - Update folder icon theme based on matugen colors
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

require_command() {
  LAST_ERROR=""
  if ! command_exists "$1"; then
    LAST_ERROR="Required command not found: $1"
    return 127
  fi
  return 0
}

ensure_directory() {
  LAST_ERROR=""
  local path="$1"
  if ! mkdir -p "$path" 2>/dev/null; then
    LAST_ERROR="Failed to create directory: $path"
    return 1
  fi
  return 0
}

set_config_value() {
  LAST_ERROR=""
  local file="$1" key="$2" delimiter="$3" value="$4" style="${5:-spaced}"
  if ! ensure_directory "$(dirname "$file")"; then
    return 1
  fi
  [[ -f "$file" ]] || touch "$file"
  local pattern="^${key}[[:space:]]*${delimiter}"
  local assignment
  case "$style" in
  compact) assignment="${key}${delimiter}${value}" ;;
  spaced | "") assignment="${key} ${delimiter} ${value}" ;;
  *)
    LAST_ERROR="Unknown style '$style' for set_config_value"
    return 1
    ;;
  esac
  local escaped_assignment="${assignment//\\/\\\\}"
  escaped_assignment="${escaped_assignment//&/\\&}"
  escaped_assignment="${escaped_assignment//|/\\|}"
  if grep -Eq "$pattern" "$file"; then
    if ! sed -i "s|${pattern}[[:space:]]*.*|${escaped_assignment}|" "$file" 2>/dev/null; then
      LAST_ERROR="Failed to update ${key} in $file"
      return 1
    fi
  else
    if ! printf '%s\n' "$assignment" >>"$file"; then
      LAST_ERROR="Failed to append ${key} to $file"
      return 1
    fi
  fi
  return 0
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

readonly FOLDER_HEX_FILE="$HOME/.cache/wal/folder-color.txt"
readonly CACHE_DIR="$HOME/.cache/wal"
readonly CACHE_NEAREST_FILE="$CACHE_DIR/folder-color.nearest"

# read_requested_hex reads the requested folder color from cache
# Returns: hex color on stdout, 1 on failure
read_requested_hex() {
  if [[ ! -f "$FOLDER_HEX_FILE" ]]; then
    log ERROR "Requested folder color not found: $FOLDER_HEX_FILE"
    return 1
  fi

  tr -d '[:space:]' <"$FOLDER_HEX_FILE"
  return 0
}

# compute_nearest_tela_color finds nearest Tela icon color match
# Arguments: $1 - hex color
# Returns: nearest color name on stdout, 127 on missing dependency, 1 on failure
compute_nearest_tela_color() {
  local hex="$1"

  if ! require_command python3; then
    log ERROR "python3 required but not found: $LAST_ERROR"
    return 127
  fi

  local nearest
  if ! nearest=$(python3 "$SCRIPT_DIR/nearest_tela_color.py" "$hex" "$CACHE_NEAREST_FILE" 2>/dev/null); then
    log ERROR "Failed to resolve nearest Tela color"
    return 1
  fi

  nearest="${nearest//$'\n'/}"

  if [[ -z "$nearest" ]]; then
    log WARN "Nearest Tela color detection returned empty result"
    return 1
  fi

  printf '%s\n' "$nearest"
  return 0
}

# resolve_icon_variant determines Tela icon theme name
# Arguments: $1 - nearest color name
# Returns: icon theme name on stdout
resolve_icon_variant() {
  local nearest_color="$1"
  local variant="${MODE:-dark}"

  if [[ -z "$nearest_color" ]]; then
    log WARN "Nearest Tela color unavailable; defaulting to 'dark'"
    nearest_color="dark"
  fi

  if [[ "$variant" != "light" && "$variant" != "dark" ]]; then
    log WARN "Invalid MODE='$variant'; defaulting to dark"
    variant="dark"
  fi

  if [[ "$nearest_color" == "dark" ]]; then
    if [[ "$variant" == "dark" ]]; then
      printf 'Tela-dark\n'
    else
      printf 'Tela\n'
    fi
    return 0
  fi

  printf 'Tela-%s-%s\n' "$nearest_color" "$variant"
  return 0
}

# apply_icon_theme sets GTK icon theme via gsettings
# Arguments: $1 - icon theme name, $2 - current icon theme value
# Returns: 0 on success/skip, 1 on failure
apply_icon_theme() {
  local icon_name="$1"
  local current="$2"

  if [[ "$current" == "$icon_name" ]]; then
    return 0
  fi

  if ! gsettings set org.gnome.desktop.interface icon-theme "$icon_name" 2>/dev/null; then
    log WARN "Failed to update GTK icon theme"
    return 1
  fi

  return 0
}

# update_qt_icon_theme updates Qt5/Qt6 icon theme configuration
# Arguments: $1 - icon theme name, $2... - associative array of current values (path=value)
# Returns: 0 on success/skip, 1 on any failure
update_qt_icon_theme() {
  local icon_name="$1"
  shift

  local qt_updated=0
  local conf current

  while [[ $# -ge 2 ]]; do
    conf="$1"
    current="$2"
    shift 2

    if [[ "$current" == "$icon_name" ]]; then
      continue
    fi

    if ! set_config_value "$conf" "icon_theme" '=' "$icon_name" compact; then
      log WARN "Failed to update Qt icon theme in $conf: $LAST_ERROR"
      return 1
    else
      qt_updated=1
    fi
  done

  if [[ $qt_updated -eq 1 ]]; then
    return 0
  fi

  return 0
}

main() {
  local requested_hex
  if ! requested_hex=$(read_requested_hex); then
    return 1
  fi

  local nearest_color
  if ! nearest_color=$(compute_nearest_tela_color "$requested_hex"); then
    return 1
  fi

  local icon_name
  icon_name=$(resolve_icon_variant "$nearest_color")

  local gtk_current
  gtk_current=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo "")

  # Read Qt configs once and store results
  local -a qt_configs=("$HOME/.config/qt5ct/qt5ct.conf" "$HOME/.config/qt6ct/qt6ct.conf")
  local -a qt_config_args=()
  local qt_needs_update=0

  for conf in "${qt_configs[@]}"; do
    if [[ -f "$conf" ]]; then
      local qt_current
      qt_current=$(grep -E '^icon_theme[[:space:]]*=' "$conf" 2>/dev/null | tail -n1 | cut -d'=' -f2- | tr -d '[:space:]' || true)
      qt_config_args+=("$conf" "$qt_current")

      if [[ "$qt_current" != "$icon_name" ]]; then
        qt_needs_update=1
      fi
    fi
  done

  # Apply updates - pass current value to avoid re-reading
  apply_icon_theme "$icon_name" "$gtk_current" || true

  if [[ ${#qt_config_args[@]} -gt 0 ]]; then
    update_qt_icon_theme "$icon_name" "${qt_config_args[@]}" || true
  fi

  # Show consolidated log
  if [[ "$gtk_current" != "$icon_name" ]] || [[ $qt_needs_update -eq 1 ]]; then
    log INFO "Updated icon theme to $icon_name"
  else
    log SKIP "Icon theme already set to $icon_name"
  fi

  return 0
}

main "$@"
