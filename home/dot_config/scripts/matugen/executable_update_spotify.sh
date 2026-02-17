#!/usr/bin/env bash
# update_spotify.sh - Apply spicetify theme for Spotify customization
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"

log() {
  local level="${1:-}"
  shift || true
  local message="$*"
  case "${level^^}" in
  INFO) printf '  %bINFO%b  %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message" >&2 ;;
  WARN) printf '  %bWARN%b  %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message" >&2 ;;
  ERROR) printf '  %bERROR%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" >&2 ;;
  SKIP) printf '  %bSKIP%b  %s\n' "\033[1;35m" "$COLOR_RESET" "$message" >&2 ;;
  *) printf '%s\n' "$message" >&2 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

readonly DESIRED_SPICETIFY_THEME="marketplace"

# ensure_spicetify_theme configures spicetify theme if not already set
# Returns: 0 on success/already set, 1 on failure
ensure_spicetify_theme() {
  local current
  current=$(spicetify config current_theme 2>/dev/null | tr -d "[:space:]'" || true)

  if [[ "$current" == "$DESIRED_SPICETIFY_THEME" ]]; then
    log SKIP "Spicetify theme already set to $DESIRED_SPICETIFY_THEME"
    return 0
  fi

  if spicetify config current_theme "$DESIRED_SPICETIFY_THEME" >/dev/null 2>&1; then
    log INFO "Configured spicetify theme: $DESIRED_SPICETIFY_THEME"
    return 0
  fi

  log ERROR "Unable to configure spicetify theme to $DESIRED_SPICETIFY_THEME (start spotify and run 'spicetify backup apply' if this is the first time)"
  return 1
}

# refresh_spotify_theme triggers live theme refresh for running Spotify
# Returns: 0 (always succeeds)
refresh_spotify_theme() {
  (
    timeout 10s spicetify -q watch -s &
    sleep 0.2
    pkill -x spicetify >/dev/null 2>&1 || true
  ) >/dev/null 2>&1 &

  log INFO "Triggered spicetify live theme refresh"
  return 0
}

# apply_spicetify_theme applies theme when Spotify is not running
# Returns: 0 on success, 1 on failure
apply_spicetify_theme() {
  if spicetify apply -q -n 2>/dev/null; then
    log INFO "Applied spicetify theme"
    return 0
  fi

  log WARN "spicetify apply reported an error, try running 'spicetify backup apply' first"
  return 1
}

main() {
  if ! command_exists spicetify; then
    log WARN "spicetify not found; skipping spotify update"
    return 0
  fi

  if ! ensure_spicetify_theme; then
    return 1
  fi

  if pgrep -x spotify >/dev/null 2>&1; then
    refresh_spotify_theme
  else
    apply_spicetify_theme || true
  fi

  return 0
}

main "$@"
