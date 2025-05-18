#!/bin/bash
# This script toggles gamemode settings in Hyprland.

if [ -f /tmp/gamemode-enabled ]; then
  hyprctl reload
  rm /tmp/gamemode-enabled
  notify-send "Gamemode deactivated" "Animations and blur enabled"
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
  touch /tmp/gamemode-enabled
  notify-send "Gamemode activated" "Animations and blur disabled"
fi
