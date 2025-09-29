#!/usr/bin/env bash
set -euo pipefail

readonly LIGHT_THEME="adw-gtk3"
readonly DARK_THEME="adw-gtk3-dark"

determine_mode() {
  local mode="${MODE:-dark}"

  case "$mode" in
  light | dark)
    printf '%s\n' "$mode"
    ;;
  *)
    log "WARN" "Invalid MODE='$mode'; defaulting to dark"
    printf 'dark\n'
    ;;
  esac
}

main() {
  if ! command_exists gsettings; then
    log "WARN" "gsettings not available; skipping GTK updates"
    return 0
  fi

  local mode
  mode=$(determine_mode)

  local desired_scheme="prefer-$mode"
  local desired_theme
  if [[ "$mode" == "dark" ]]; then
    desired_theme="$DARK_THEME"
  else
    desired_theme="$LIGHT_THEME"
  fi

  set_gsetting_if_needed org.gnome.desktop.interface color-scheme "$desired_scheme" "GTK color-scheme"
  set_gsetting_if_needed org.gnome.desktop.interface gtk-theme "$desired_theme" "GTK theme"
}

main "$@"
