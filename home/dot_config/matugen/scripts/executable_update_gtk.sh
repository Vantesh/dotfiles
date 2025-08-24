#!/usr/bin/env bash
set -euo pipefail

line='@import "colors.css";'
mode="${MODE:-dark}"

files=(
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-3.0/gtk-dark.css"
  "$HOME/.config/gtk-4.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk-dark.css"
)

for file in "${files[@]}"; do
  mkdir -p "${file%/*}"
  if [[ -L $file ]]; then
    rm -f "$file"
    echo "$line" >"$file"
  else
    grep -Fxq "$line" "$file" 2>/dev/null || echo "$line" >"$file"
  fi
done

gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
