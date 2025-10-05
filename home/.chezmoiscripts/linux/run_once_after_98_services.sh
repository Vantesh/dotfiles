#!/usr/bin/env bash
# 98_services.sh - Enable core services and configure system utilities
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly -a USER_SERVICES=(
  "gnome-keyring-daemon"
  "hypridle"
  "mpris-proxy"
)

readonly -a SYSTEM_SERVICES=(
  "NetworkManager"
  "bluetooth"
  "udisks2"
  "ufw"
)

readonly -a PACMAN_SERVICES=(
  "reflector.timer"
  "pacman-filesdb-refresh.timer"
  "paccache.timer"
)

enable_configured_services() {
  local -a failed_services=()
  local scope

  for scope in user system; do
    local -a scope_services=()

    if [[ "$scope" == "user" ]]; then
      scope_services=("${USER_SERVICES[@]}")
    else
      scope_services=("${SYSTEM_SERVICES[@]}")
    fi

    if ((${#scope_services[@]} == 0)); then
      continue
    fi

    local service
    for service in "${scope_services[@]}"; do
      if ! enable_service "$service" "$scope"; then
        local error_msg="$LAST_ERROR"

        if [[ "$error_msg" == "Service not found: "* ]]; then
          log SKIP "$service ($scope) not available"
        else
          failed_services+=("$service ($scope): $error_msg")
          log WARN "Failed to enable $service ($scope): $error_msg"
        fi
      else
        log INFO "${COLOR_INFO}${service}${COLOR_RESET} enabled (${scope})"
      fi
    done
  done

  if ((${#failed_services[@]} > 0)); then
    log WARN "Some services failed to enable: ${failed_services[*]}"
  fi

  if command_exists pacman; then
    local pacman_service
    for pacman_service in "${PACMAN_SERVICES[@]}"; do
      if ! enable_service "$pacman_service" "system"; then
        local error_msg="$LAST_ERROR"

        if [[ "$error_msg" == "Service not found: "* ]]; then
          log SKIP "$pacman_service (system) not available"
        else
          log WARN "Failed to enable $pacman_service (system): $error_msg"
        fi
      else
        log INFO "${COLOR_INFO}${pacman_service}${COLOR_RESET} enabled (system)"
      fi
    done
  else
    local pacman_service
    for pacman_service in "${PACMAN_SERVICES[@]}"; do
      log SKIP "$pacman_service (system) skipped (pacman not available)"
    done
  fi

  return 0
}

configure_ufw() {
  if ! command_exists "ufw"; then
    log SKIP "UFW not installed, skipping firewall configuration"
    return 0
  fi

  log STEP "Configuring UFW"

  if ! sudo ufw --force enable >/dev/null 2>&1; then
    log WARN "Failed to enable UFW"
    return 0
  fi

  log INFO "Enabled UFW"

  local -a allow_rules=(
    "53317/udp"
    "53317/tcp"
    "443/tcp"
    "80/tcp"
  )

  local rule
  for rule in "${allow_rules[@]}"; do
    if sudo ufw allow "$rule" >/dev/null 2>&1; then
      log INFO "Allowed $rule"
    else
      log WARN "Failed to allow $rule"
    fi
  done

  if sudo ufw limit 22/tcp >/dev/null 2>&1; then
    log INFO "Limited SSH (22/tcp)"
  else
    log WARN "Failed to limit SSH (22/tcp)"
  fi

  if sudo ufw default deny incoming >/dev/null 2>&1; then
    log INFO "Set default policy: deny incoming"
  else
    log WARN "Failed to set default policy: deny incoming"
  fi

  if sudo ufw default allow outgoing >/dev/null 2>&1; then
    log INFO "Set default policy: allow outgoing"
  else
    log WARN "Failed to set default policy: allow outgoing"
  fi

  return 0
}

disable_networkd_wait_online() {
  local service="systemd-networkd-wait-online.service"

  if ! command_exists "systemctl"; then
    log SKIP "systemctl not available, skipping $service adjustments"
    return 0
  fi

  if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
    log SKIP "$service not present"
    return 0
  fi

  if systemctl is-active --quiet "$service" || systemctl is-enabled --quiet "$service"; then
    if sudo systemctl disable --now "$service" >/dev/null 2>&1; then
      log INFO "Disabled $service"
    else
      log WARN "Failed to disable $service"
    fi
  fi

  if sudo systemctl mask "$service" >/dev/null 2>&1; then
    log INFO "Masked $service"
  else
    log WARN "Failed to mask $service"
  fi

  return 0
}

update_locate_database() {
  if ! command_exists "updatedb"; then
    log SKIP "updatedb not available, skipping locate database update"
    return 0
  fi

  log INFO "Updating locate database"

  if sudo updatedb >/dev/null 2>&1; then
    log INFO "updatedb completed successfully"
  else
    log WARN "updatedb encountered issues"
  fi

  return 0
}

main() {
  print_box "Services"
  log STEP "Configuring services"

  enable_configured_services
  configure_ufw
  disable_networkd_wait_online
  update_locate_database

}

main "$@"
