#!/bin/bash
apps=(
  "clipse -listen"
  "udiskie &"
  "pypr &"
  "swaync &"

)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
