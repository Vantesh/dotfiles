#!/usr/bin/env bash
# Application preferences are independent of the desktop theme and UI font.
set -euo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
  printf 'gsettings not available; skipping Nautilus preferences\n' >&2
  exit 0
fi

gsettings set org.gnome.nautilus.icon-view default-zoom-level "small-plus"
gsettings set org.gnome.nautilus.preferences show-delete-permanently true
