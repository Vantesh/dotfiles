#!/usr/bin/env bash
set -euo pipefail

readonly SERVICES_TO_RESTART=("xdg-desktop-portal-gtk")

for service in "${SERVICES_TO_RESTART[@]}"; do
  if systemctl --user is-active --quiet "$service"; then
    systemctl --user restart "$service" &>/dev/null || true
  fi
done

pkill -f "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" &>/dev/null || true
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null &

# Background refresh
pkill -USR1 -x nvim 2>/dev/null || true
pkill -USR1 -x cava 2>/dev/null || true
