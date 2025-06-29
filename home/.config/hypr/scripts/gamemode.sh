#!/bin/bash
# This script toggles gamemode settings in Hyprland.

if [ -f /tmp/gamemode-enabled ]; then
  hyprctl reload
  # enable waybar
  waybar &
  rm /tmp/gamemode-enabled
  notify-send "Gamemode deactivated" "Default settings restored"
else
  hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword decoration:active_opacity 1;\
        keyword decoration:inactive_opacity 1;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
  # disable waybar
  killall waybar
  touch /tmp/gamemode-enabled
  notify-send "Gamemode activated" "Animations and blur disabled"
fi
