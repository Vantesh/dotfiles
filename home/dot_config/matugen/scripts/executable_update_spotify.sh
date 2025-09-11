#!/usr/bin/env bash
set -euo pipefail

ensure_spicetify_theme() {
  local desired="marketplace"
  local current

  current=$(spicetify config current_theme 2>/dev/null || true)

  if [[ "$current" != "$desired" ]]; then
    if ! spicetify config current_theme "$desired" &>/dev/null; then
      echo "Echo: Failed to set spicetify theme to '$desired'"
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
  if ! command -v spicetify &>/dev/null; then
    echo "Error: spicetify not found in PATH"
    return 1
  fi

  ensure_spicetify_theme || return 1

  if pgrep -x spotify &>/dev/null; then
    trigger_spicetify_refresh
  else
    spicetify apply -q || log_error "spicetify apply failed"
  fi
}

main "$@"
