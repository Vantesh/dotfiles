#!/usr/bin/env bash
# update_gtk.sh - Update GTK theme and color scheme based on current mode
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

readonly LIGHT_THEME="adw-gtk3"
readonly DARK_THEME="adw-gtk3-dark"

main() {
  if ! command_exists gsettings; then
    log WARN "gsettings not available; skipping GTK updates"
    return 0
  fi

  local mode="${MODE:-dark}"

  case "$mode" in
  light | dark) ;;
  *)
    log WARN "Invalid MODE='$mode'; defaulting to dark"
    mode="dark"
    ;;
  esac

  local desired_scheme="prefer-$mode"
  local desired_theme

  if [[ "$mode" == "dark" ]]; then
    desired_theme="$DARK_THEME"
  else
    desired_theme="$LIGHT_THEME"
  fi

  # Temporarily capture the state
  local scheme_current theme_current
  scheme_current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || echo "")
  theme_current=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || echo "")

  local updates_needed=0
  [[ "$scheme_current" != "$desired_scheme" ]] && updates_needed=1
  [[ "$theme_current" != "$desired_theme" ]] && updates_needed=1

  if [[ $updates_needed -eq 0 ]]; then
    log SKIP "GTK color-scheme and theme already configured"
    return 0
  fi

  # Apply updates silently
  gsettings set org.gnome.desktop.interface color-scheme "$desired_scheme" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "$desired_theme" 2>/dev/null || true

  log INFO "Updated GTK color-scheme to $desired_scheme and theme to $desired_theme"

  return 0
}

main "$@"
