#!/usr/bin/env bash
set -euo pipefail

readonly SERVICES_TO_RESTART=("xdg-desktop-portal-gtk")
readonly POLKIT_AGENT="/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"

refresh_user_services() {
  for service in "${SERVICES_TO_RESTART[@]}"; do
    restart_user_service "$service"
  done
}

ensure_polkit_agent() {
  if [[ ! -x "$POLKIT_AGENT" ]]; then
    log "WARN" "Polkit agent binary not found at $POLKIT_AGENT"
    return 0
  fi

  pkill -f "polkit-gnome-authentication-agent-1" >/dev/null 2>&1 || true

  if nohup "$POLKIT_AGENT" >/dev/null 2>&1 & then
    disown || true
    log "INFO" "Launched polkit authentication agent"
  else
    log "WARN" "Failed to start polkit authentication agent"
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
