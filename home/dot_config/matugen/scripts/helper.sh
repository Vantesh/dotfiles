#!/usr/bin/env bash
# Shared helper functions for matugen scripts.

log() {
  local level=$1
  shift || true
  local message="$*"
  local color="\033[0m"
  case "${level^^}" in
  INFO) color="\033[1;32m" ;;
  WARN) color="\033[1;33m" ;;
  ERROR) color="\033[1;31m" ;;
  esac
  printf '%b[%s]%b %s\n' "$color" "${level^^}" "\033[0m" "$message" >&2
}

die() {
  local code=1
  local message="Unexpected failure"
  if [[ $# -gt 1 ]]; then
    code=$1
    shift
    message=${*:-$message}
  elif [[ $# -eq 1 ]]; then
    message=$1
  fi
  log "ERROR" "$message"
  exit "$code"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local binary="$1"
  if ! command_exists "$binary"; then
    log "ERROR" "Required command not found: $binary"
    return 1
  fi
}

ensure_directory() {
  local path="$1"
  mkdir -p "$path"
}

set_gsetting_if_needed() {
  local schema="$1" key="$2" desired="$3"
  local label="${4:-$schema::$key}"

  if ! command_exists gsettings; then
    log "WARN" "gsettings unavailable; skipping update for $label"
    return 0
  fi

  local current
  current=$(gsettings get "$schema" "$key" 2>/dev/null | tr -d "'" || true)

  if [[ "$current" == "$desired" ]]; then
    return 0
  fi

  if gsettings set "$schema" "$key" "$desired" 2>/dev/null; then
    log "INFO" "Updated $label to $desired"
    return 0
  fi

  log "ERROR" "Failed to set $label to $desired"
  return 1
}

# set_config_value FILE KEY DELIMITER VALUE [STYLE]
# Ensures the config file contains the requested assignment, appending if missing.
# STYLE can be:
#   spaced (default) -> KEY DELIMITER VALUE
#   compact          -> KEYDELIMITERVALUE
set_config_value() {
  local file="$1" key="$2" delimiter="$3" value="$4" style="${5:-spaced}"

  ensure_directory "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"

  local pattern="^${key}[[:space:]]*${delimiter}"
  local assignment
  case "$style" in
  compact) assignment="${key}${delimiter}${value}" ;;
  spaced | "") assignment="${key} ${delimiter} ${value}" ;;
  *)
    log "WARN" "Unknown style '$style' for set_config_value; defaulting to spaced"
    assignment="${key} ${delimiter} ${value}"
    ;;
  esac

  local escaped_assignment="${assignment//\\/\\\\}"
  escaped_assignment="${escaped_assignment//&/\\&}"
  escaped_assignment="${escaped_assignment//|/\\|}"

  if grep -Eq "$pattern" "$file"; then
    if ! sed -i "s|${pattern}[[:space:]]*.*|${escaped_assignment}|" "$file"; then
      log "ERROR" "Failed to update ${key} in $file"
      return 1
    fi
  else
    if ! printf '%s\n' "$assignment" >>"$file"; then
      log "ERROR" "Failed to append ${key} to $file"
      return 1
    fi
  fi
}

send_signal_if_running() {
  local signal="$1" process_name="$2"

  if pkill -0 -x "$process_name" 2>/dev/null; then
    if ! pkill "-$signal" -x "$process_name" 2>/dev/null; then
      log "WARN" "Unable to send SIG${signal#SIG} to $process_name"
      return 1
    fi
  fi

  return 0
}

restart_user_service() {
  local service="$1"

  if ! command_exists systemctl; then
    log "WARN" "systemctl unavailable; cannot restart $service"
    return 0
  fi

  if systemctl --user is-active --quiet "$service"; then
    if ! systemctl --user restart "$service" >/dev/null 2>&1; then
      log "WARN" "Failed to restart user service: $service"
      return 1
    fi

  fi

  return 0
}
