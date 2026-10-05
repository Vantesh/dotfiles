#!/usr/bin/env bash
# Apply the Tela color and mode selected by Noctalia's template engine.
set -euo pipefail

if [[ $# -ne 2 || -z "$1" || ( "$2" != dark && "$2" != light ) ]]; then
  printf 'Usage: update_folders.sh <tela_color> <dark|light>\n' >&2
  exit 1
fi

color="$1"
mode="$2"
theme="Tela-$color-$mode"
# Tela's default blue variant has no color suffix.
if [[ "$color" == dark ]]; then
  theme="Tela"
  [[ "$mode" != dark ]] || theme+="-dark"
fi

failed=0
if command -v gsettings >/dev/null 2>&1; then
  current=$(gsettings get org.gnome.desktop.interface icon-theme || true)
  if [[ "$current" != "'$theme'" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "$theme" || failed=1
  fi
else
  printf 'gsettings not found; skipping GTK icon theme\n' >&2
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
for qt in qt5ct qt6ct; do
  conf="$config_dir/$qt/$qt.conf"
  [[ -f "$conf" ]] || continue
  if grep -Eq "^icon_theme[[:space:]]*=[[:space:]]*${theme}[[:space:]]*$" "$conf"; then
    continue
  fi
  if grep -Eq '^icon_theme[[:space:]]*=' "$conf"; then
    sed -i "s/^icon_theme[[:space:]]*=.*/icon_theme=$theme/" "$conf" || failed=1
  else
    printf '\nicon_theme=%s\n' "$theme" >>"$conf" || failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  printf 'Failed to apply Tela icon theme: %s\n' "$theme" >&2
  exit 1
fi
printf 'Tela icon theme: %s\n' "$theme"
