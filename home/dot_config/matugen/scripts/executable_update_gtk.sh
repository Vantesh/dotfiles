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
    printf '%s\n' "$line" >"$file"
  else
    if [[ -f "$file" ]]; then
      if ! grep -Fxq "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" >"$file"
      fi
    else
      printf '%s\n' "$line" >"$file"
    fi
  fi
done

current_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "'prefer-dark'")
current_scheme=${current_scheme//\'/}
if [[ "$current_scheme" != "prefer-$mode" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
fi
