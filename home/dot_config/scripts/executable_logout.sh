#!/usr/bin/env bash
# Vscode does not handle uwsm or loginctl logouts properly.
# This script kills the vscode process and then logs out the user.

set -euo pipefail

EDITOR_CLASS="code"

case "${XDG_CURRENT_DESKTOP:-}" in
Hyprland)
  pid=$(hyprctl clients -j | jq -r --arg app "$EDITOR_CLASS" '.[] | select(.class==$app) | .pid' | head -n1)
  ;;
niri)
  pid=$(niri clients -j | jq -r --arg app "$EDITOR_CLASS" '.[] | select(.class==$app) | .pid' | head -n1)
  ;;
*)
  pid=$(pgrep -x "$EDITOR_CLASS" | head -n1 || true)
  ;;
esac

if [[ -n "${pid:-}" ]]; then
  kill -TERM "${pid}" 2>/dev/null || true
fi

if env | grep -q '^UWSM_'; then
  exec uwsm stop
else
  exec loginctl terminate-user "$USER"
fi
