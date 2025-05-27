#!/bin/bash
apps=(
  "clipse -listen"
  "udiskie"
  "pypr"

)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
