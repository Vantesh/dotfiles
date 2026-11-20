#!/bin/sh
set -eu

mode="{{ mode }}"
case "$mode" in
  dark)
    hyprcursor_theme=MacTahoe-dark-hyprcursor
    xcursor_theme=MacTahoe-dark-cursors
    icon_theme=Colloid-Dark
    ;;
  light)
    hyprcursor_theme=MacTahoe-hyprcursor
    xcursor_theme=MacTahoe-cursors
    icon_theme=Colloid-Light
    ;;
  *) exit 1 ;;
esac
cursor_size=24

gsettings set org.gnome.desktop.interface cursor-theme "$xcursor_theme"
gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"
gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl setcursor "$hyprcursor_theme" "$cursor_size"
fi
