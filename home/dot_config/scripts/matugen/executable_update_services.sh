#!/usr/bin/env bash
# update_services.sh - Refresh system services and polkit agent for theme changes
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

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

main() {
  refresh_user_services
  ensure_polkit_agent
  refresh_signals

  return 0
}

main "$@"
