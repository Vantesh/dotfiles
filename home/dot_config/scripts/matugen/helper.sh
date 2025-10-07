#!/usr/bin/env bash
# helper.sh - Shared helper functions for matugen scripts
# Exit codes: 0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

set -euo pipefail

export LAST_ERROR="${LAST_ERROR:-}"

readonly COLOR_RESET="\033[0m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_MAGENTA="\033[1;35m"
readonly COLOR_BLUE="\033[1;34m"

# log outputs formatted log messages to stderr
# Arguments: $1 - level (INFO|WARN|ERROR|SKIP|STEP), $@ - message
# Returns: 0 on success, 1 on invalid arguments
log() {
  local level="${1:-}"
  shift || true
  local message="$*"

  if [[ -z "$level" ]] || [[ -z "$message" ]]; then
    printf '[ERROR] log() requires a level and a message\n' >&2
    return 1
  fi

  local color="$COLOR_RESET"
  case "${level^^}" in
  INFO) color="$COLOR_GREEN" ;;
  WARN) color="$COLOR_YELLOW" ;;
  ERROR) color="$COLOR_RED" ;;
  SKIP) color="$COLOR_MAGENTA" ;;
  STEP)
    printf '\n%b::%b %s\n\n' "$COLOR_BLUE" "$COLOR_RESET" "$message" >&2
    return 0
    ;;
  *)
    printf '[ERROR] Invalid log level: %s\n' "$level" >&2
    return 1
    ;;
  esac

  printf '%b%s:%b %s\n' "$color" "${level^^}" "$COLOR_RESET" "$message" >&2
}

# die logs error and exits with specified code
# Arguments: $1 - optional exit code (default 1), $@ - error message
# Returns: exits process
die() {
  local exit_code=1
  local message="Unexpected failure"

  if [[ $# -gt 1 && "$1" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
    message="${*:-$message}"
  elif [[ $# -eq 1 ]]; then
    message="$1"
  fi

  log ERROR "$message"
  exit "$exit_code"
}

# command_exists checks if a command is available
# Arguments: $1 - command name
# Returns: 0 if exists, 1 if not
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# require_command validates command availability and sets LAST_ERROR
# Arguments: $1 - command name
# Returns: 0 if exists, 127 if not
require_command() {
  LAST_ERROR=""
  local binary="$1"

  if ! command_exists "$binary"; then
    LAST_ERROR="Required command not found: $binary"
    return 127
  fi

  return 0
}

# ensure_directory creates directory if it doesn't exist
# Arguments: $1 - directory path
# Returns: 0 on success, 1 on failure
ensure_directory() {
  LAST_ERROR=""
  local path="$1"

  if ! mkdir -p "$path" 2>/dev/null; then
    LAST_ERROR="Failed to create directory: $path"
    return 1
  fi

  return 0
}

# set_config_value ensures config file contains requested assignment
# Arguments: $1 - file, $2 - key, $3 - delimiter, $4 - value, $5 - style (spaced|compact)
# Returns: 0 on success, 1 on failure
set_config_value() {
  LAST_ERROR=""
  local file="$1" key="$2" delimiter="$3" value="$4" style="${5:-spaced}"

  if ! ensure_directory "$(dirname "$file")"; then
    return 1
  fi

  [[ -f "$file" ]] || touch "$file"

  local pattern="^${key}[[:space:]]*${delimiter}"
  local assignment

  case "$style" in
  compact) assignment="${key}${delimiter}${value}" ;;
  spaced | "") assignment="${key} ${delimiter} ${value}" ;;
  *)
    LAST_ERROR="Unknown style '$style' for set_config_value"
    return 1
    ;;
  esac

  local escaped_assignment="${assignment//\\/\\\\}"
  escaped_assignment="${escaped_assignment//&/\\&}"
  escaped_assignment="${escaped_assignment//|/\\|}"

  if grep -Eq "$pattern" "$file"; then
    if ! sed -i "s|${pattern}[[:space:]]*.*|${escaped_assignment}|" "$file" 2>/dev/null; then
      LAST_ERROR="Failed to update ${key} in $file"
      return 1
    fi
  else
    if ! printf '%s\n' "$assignment" >>"$file"; then
      LAST_ERROR="Failed to append ${key} to $file"
      return 1
    fi
  fi

  return 0
}

# send_signal_if_running sends signal to process if running
# Arguments: $1 - signal name, $2 - process name
# Returns: 0 on success or process not running, 1 on failure
send_signal_if_running() {
  LAST_ERROR=""
  local signal="$1" process_name="$2"

  if ! pkill -0 -x "$process_name" 2>/dev/null; then
    return 0
  fi

  if ! pkill "-$signal" -x "$process_name" 2>/dev/null; then
    LAST_ERROR="Unable to send SIG${signal#SIG} to $process_name"
    return 1
  fi

  return 0
}

# restart_user_service restarts a systemd user service if active
# Arguments: $1 - service name
# Returns: 0 on success or systemctl unavailable, 1 on failure
restart_user_service() {
  LAST_ERROR=""
  local service="$1"

  if ! command_exists systemctl; then
    LAST_ERROR="systemctl unavailable"
    return 1
  fi

  if ! systemctl --user is-active --quiet "$service" 2>/dev/null; then
    return 0
  fi

  if ! systemctl --user restart "$service" >/dev/null 2>&1; then
    LAST_ERROR="Failed to restart user service: $service"
    return 1
  fi

  return 0
}
