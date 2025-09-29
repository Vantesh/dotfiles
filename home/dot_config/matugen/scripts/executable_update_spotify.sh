#!/usr/bin/env bash
set -euo pipefail

readonly DESIRED_SPICETIFY_THEME="marketplace"

ensure_spicetify_theme() {
  local current
  current=$(spicetify config current_theme 2>/dev/null | tr -d "[:space:]'" || true)

  if [[ "$current" == "$DESIRED_SPICETIFY_THEME" ]]; then
    return 0
  fi

  if spicetify config current_theme "$DESIRED_SPICETIFY_THEME" &>/dev/null; then
    log "INFO" "Configured spicetify theme: $DESIRED_SPICETIFY_THEME"
    return 0
  fi

  log "ERROR" "Unable to configure spicetify theme to $DESIRED_SPICETIFY_THEME"
  return 1
}

refresh_spotify_theme() {

  (
    timeout 10s spicetify -q watch -s &
    sleep 0.2
    pkill -x spicetify >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &

  log "INFO" "Triggered spicetify live theme refresh"
}

apply_spicetify_theme() {
  if spicetify apply -q -n; then
    log "INFO" "Applied spicetify theme"
  else
    log "WARN" "spicetify apply reported an error, try running 'spicetify backup apply' first"
  fi
}

main() {
  if ! command_exists spicetify; then
    log "WARN" "spicetify not found; skipping spotify update"
    return 0
  fi

  ensure_spicetify_theme || return 1

  if pgrep -x spotify >/dev/null 2>&1; then
    refresh_spotify_theme
  else
    apply_spicetify_theme
  fi
}

main "$@"
