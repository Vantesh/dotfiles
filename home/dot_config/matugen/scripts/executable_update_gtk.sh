#!/usr/bin/env bash
set -euo pipefail

mode="${MODE:-dark}"

current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")
current_scheme=${current_scheme//\'/}

if [[ "$current_scheme" != "prefer-$mode" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
fi

# Set gtk theme explicitly for light and dark modes
if [[ "$mode" == "light" ]]; then
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
else
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
fi
