#!/usr/bin/env bash
set -euo pipefail

readonly SERVICES_TO_RESTART=("xdg-desktop-portal-gtk")

for service in "${SERVICES_TO_RESTART[@]}"; do
  if systemctl --user is-active --quiet "$service"; then
    systemctl --user restart "$service" &>/dev/null &
  fi
done

pkill "polkit-gnome-au" >/dev/null || true
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null &

# Background refresh signals only if processes present
pkill -0 -x nvim 2>/dev/null && pkill -USR1 -x nvim 2>/dev/null || true
pkill -0 -x cava 2>/dev/null && pkill -USR1 -x cava 2>/dev/null || true
