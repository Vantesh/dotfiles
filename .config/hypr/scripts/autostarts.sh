#!/bin/bash
apps=(
  "swww-daemon"
  "clipse -listen"
  "udiskie -q"
  "pypr"
  "hyprpanel"

)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
