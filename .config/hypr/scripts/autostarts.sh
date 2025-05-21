#!/bin/bash
apps=(
  "clipse -listen"
  "udiskie &"
  "pypr --debug /tmp/pypr.log"

)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
