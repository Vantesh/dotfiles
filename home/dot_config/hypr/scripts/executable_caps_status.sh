#!/bin/bash

# Requires hyprctl and jq
# Checks if Caps Lock is active on the main keyboard

caps_state=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .capsLock')

if [ "$caps_state" = "true" ]; then
  echo "<b><span color='red'>CAPS LOCK ON</span></b>"
else
  echo ""
fi
