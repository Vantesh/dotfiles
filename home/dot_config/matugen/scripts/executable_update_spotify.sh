#!/usr/bin/env bash
set -euo pipefail

log_error() { echo "Error: $*" >&2; }

# Require spicetify and running spotify, otherwise noop
command -v spicetify &>/dev/null || exit 0
pgrep -x spotify &>/dev/null || exit 0

# Ensure marketplace theme is set
if [[ "$(spicetify config current_theme 2>/dev/null)" != "marketplace" ]]; then
  spicetify config current_theme marketplace &>/dev/null || {
    log_error "Failed to set spicetify theme"
    exit 1
  }
fi

# Trigger incremental refresh briefly and exit
{
  timeout 10s spicetify -q watch -s &
  watch_pid=$!
  sleep 2
  kill "$watch_pid" 2>/dev/null || true
} &>/dev/null &
