#!/usr/bin/env bash
set -euo pipefail

log_error() { printf 'Error: %s\n' "$*" >&2; }

have_cmd() { command -v "$1" &>/dev/null; }
is_running() { pgrep -x "$1" &>/dev/null; }

ensure_spicetify_theme() {
  local theme="marketplace"
  local current

  current=$(spicetify config current_theme 2>/dev/null || echo "")

  if [[ "$current" != "$theme" ]]; then
    if ! spicetify config current_theme "$theme" &>/dev/null; then
      log_error "Failed to set spicetify theme"
      exit 1
    fi
  fi
}

trigger_spicetify_refresh() {
  local pid
  timeout 10s spicetify -q watch -s &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true' EXIT
  sleep 2
  kill "$pid" 2>/dev/null || true
  trap - EXIT
}

main() {
  # Require spicetify and running Spotify, otherwise noop
  have_cmd spicetify || exit 0
  is_running spotify || exit 0

  ensure_spicetify_theme
  trigger_spicetify_refresh &>/dev/null &
}

main "$@"
