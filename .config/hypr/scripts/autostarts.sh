#!/bin/bash
exec >/tmp/autostart.log 2>&1

apps=(
  "hyprpanel"
  "clipse -listen"
  "hyprpaper"
  "swww-daemon"
  "hypridle"
)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
