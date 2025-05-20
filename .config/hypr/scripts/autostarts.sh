#!/bin/bash

apps=(
  "clipse -listen"
  "udiskie &"
)

for app in "${apps[@]}"; do
  app2unit -- $app &
done
