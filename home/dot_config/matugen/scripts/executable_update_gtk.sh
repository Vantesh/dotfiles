#!/usr/bin/env bash

set -euo pipefail

GTK_IMPORT_LINE='@import "colors.css";'
GTK_CSS_FILES=(
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-3.0/gtk-dark.css"
  "$HOME/.config/gtk-4.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk-dark.css"
)

for file in "${GTK_CSS_FILES[@]}"; do
  if [[ -L "$file" ]] || ! grep -Fxq "$GTK_IMPORT_LINE" "$file" 2>/dev/null; then
    mkdir -p "$(dirname "$file")"
    echo "$GTK_IMPORT_LINE" >"${file}.tmp"
    mv "${file}.tmp" "$file"
  fi
done

gtk_pref="prefer-${MODE:-dark}"
command -v gsettings &>/dev/null &&
  gsettings set org.gnome.desktop.interface color-scheme "$gtk_pref" 2>/dev/null || true
