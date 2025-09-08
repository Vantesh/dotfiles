#!/usr/bin/env bash
set -euo pipefail

mode="${MODE:-dark}"
LIGHT_THEME="adw-gtk3"
DARK_THEME="adw-gtk3-dark"

get_gsetting() {
  gsettings get "$1" "$2" 2>/dev/null | tr -d "'"
}

current_scheme=$(get_gsetting org.gnome.desktop.interface color-scheme || echo "prefer-dark")
current_theme=$(get_gsetting org.gnome.desktop.interface gtk-theme || echo "$DARK_THEME")

desired_scheme="prefer-$mode"
desired_theme=$([[ $mode == "dark" ]] && echo "$DARK_THEME" || echo "$LIGHT_THEME")

if [[ $current_scheme != "$desired_scheme" ]]; then
  echo "Info: Switching color scheme to: $desired_scheme"
  gsettings set org.gnome.desktop.interface color-scheme "$desired_scheme"
fi

if [[ $current_theme != "$desired_theme" ]]; then
  echo "Info: Switching GTK theme to: $desired_theme"
  gsettings set org.gnome.desktop.interface gtk-theme "$desired_theme"
fi
