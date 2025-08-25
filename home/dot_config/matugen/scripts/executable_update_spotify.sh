#!/usr/bin/env bash
set -euo pipefail

log_error() { printf 'Error: %s\n' "$*\n" >&2; }

have_cmd() { command -v "$1" &>/dev/null; }
is_running() { pgrep -x "$1" &>/dev/null; }

ensure_spicetify_theme() {
  local desired="marketplace"
  local current

  current=$(spicetify config current_theme 2>/dev/null || true)

  if [[ "$current" != "$desired" ]]; then
    if ! spicetify config current_theme "$desired" &>/dev/null; then
      log_error "Failed to set spicetify theme to '$desired'"
      return 1
    fi
  fi
}

trigger_spicetify_refresh() {
    (
      timeout 10s spicetify -q watch -s &
      sleep 1
      pkill -x spicetify || true
    ) &>/dev/null &
}

main() {
  # Exit early if spicetify is not installed or Spotify not running
  have_cmd spicetify || exit 0
  is_running spotify || exit 0

  ensure_spicetify_theme || exit 1
  trigger_spicetify_refresh
}

main "$@"
