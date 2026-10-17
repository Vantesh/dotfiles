#!/bin/sh
set -eu

mode="{{ mode }}"
case "$mode" in
  dark)
    hyprcursor_theme=macOS-hypr
    xcursor_theme=macOS-White
    ;;
  light)
    hyprcursor_theme=macOS-hypr-dark
    xcursor_theme=macOS
    ;;
  *) exit 1 ;;
esac
cursor_size=24

gsettings set org.gnome.desktop.interface cursor-theme "$xcursor_theme"
gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl setcursor "$hyprcursor_theme" "$cursor_size"
fi
