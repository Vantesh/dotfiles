#!/usr/bin/env bash
# update_services.sh - Refresh system services and polkit agent for theme changes
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

LAST_ERROR=""
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_MAGENTA="\033[1;35m"
COLOR_BLUE="\033[1;34m"

log() {
  local level="${1:-}"
  shift || true
  local message="$*"
  case "${level^^}" in
  INFO) printf '  %bINFO%b  %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message" >&2 ;;
  WARN) printf '  %bWARN%b  %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message" >&2 ;;
  ERROR) printf '  %bERROR%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" >&2 ;;
  SKIP) printf '  %bSKIP%b  %s\n' "$COLOR_MAGENTA" "$COLOR_RESET" "$message" >&2 ;;
  STEP) printf '\n%b::%b %s\n\n' "$COLOR_BLUE" "$COLOR_RESET" "$message" >&2 ;;
  *) printf '%s\n' "$message" >&2 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

require_command() {
  LAST_ERROR=""
  if ! command_exists "$1"; then
    LAST_ERROR="Required command not found: $1"
    return 127
  fi
  return 0
}

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

readonly -a SERVICES_TO_RESTART=("xdg-desktop-portal-gtk")
readonly -a POLKIT_AGENTS=(
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  "/usr/libexec/polkit-mate-authentication-agent-1"
)

# refresh_user_services restarts systemd user services for theme updates
# Returns: 0 (always succeeds, logs failures)
refresh_user_services() {
  for service in "${SERVICES_TO_RESTART[@]}"; do
    if ! restart_user_service "$service"; then
      log WARN "Failed to restart $service: $LAST_ERROR"
    fi
  done

  return 0
}

# ensure_polkit_agent starts polkit authentication agent if available
# Returns: 0 (always succeeds, logs warnings)
ensure_polkit_agent() {
  local agent="" agent_name=""

  for candidate in "${POLKIT_AGENTS[@]}"; do
    if [[ -x "$candidate" ]]; then
      agent="$candidate"
      agent_name="$(basename "$agent")"
      break
    fi
  done

  if [[ -z "$agent" ]]; then
    log WARN "No polkit agent found"
    return 0
  fi

  pkill -f "$agent_name" >/dev/null 2>&1 || true

  if nohup "$agent" >/dev/null 2>&1 & then
    disown || true
    log INFO "Launched polkit authentication agent: $agent_name"
  else
    log WARN "Failed to start polkit authentication agent: $agent_name"
  fi

  return 0
}

# refresh_signals sends reload signals to running applications
# Returns: 0 (always succeeds, logs failures)
refresh_signals() {
  if ! send_signal_if_running USR1 nvim; then
    log WARN "Failed to signal nvim: $LAST_ERROR"
  fi

  if ! send_signal_if_running USR1 cava; then
    log WARN "Failed to signal cava: $LAST_ERROR"
  fi

  return 0
}

# refresh_bat_cache updates bat's syntax cache when available
refresh_bat_cache() {
  if ! command_exists bat; then
    return 0
  fi

  log INFO "Refreshing bat syntax cache"

  if ! bat cache --build >/dev/null 2>&1; then
    log WARN "bat cache refresh completed with warnings"
    return 1
  fi

  return 0
}

main() {
  refresh_user_services
  ensure_polkit_agent
  refresh_signals
  # Bat cache refresh (best-effort)
  refresh_bat_cache || true

  return 0
}

main "$@"
