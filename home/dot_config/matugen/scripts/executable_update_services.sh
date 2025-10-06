#!/usr/bin/env bash
set -euo pipefail

readonly SERVICES_TO_RESTART=("xdg-desktop-portal-gtk")
readonly -a POLKIT_AGENTS=(
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
  "/usr/libexec/polkit-mate-authentication-agent-1"
)

refresh_user_services() {
  for service in "${SERVICES_TO_RESTART[@]}"; do
    restart_user_service "$service"
  done
}

ensure_polkit_agent() {
  local agent=""
  local agent_name=""

  for candidate in "${POLKIT_AGENTS[@]}"; do
    if [[ -x "$candidate" ]]; then
      agent="$candidate"
      agent_name=$(basename "$agent")
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
}

refresh_signals() {
  send_signal_if_running "USR1" "nvim"
  send_signal_if_running "USR1" "cava"
}

main() {
  refresh_user_services
  ensure_polkit_agent
  refresh_signals
}

main "$@"
