#!/bin/bash
apps=(
  "wpaperd -d"
  "clipse -listen"
  "udiskie -q"
  "pypr"
  "hyprpanel"

)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
