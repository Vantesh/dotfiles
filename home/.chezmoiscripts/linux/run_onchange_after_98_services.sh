#!/usr/bin/env bash
# 98_services.sh - Enable core services and configure system utilities
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

# shellcheck disable=SC2034
readonly -a USER_SERVICES=(
  "gnome-keyring-daemon.socket"
  "gnome-keyring-daemon.service"
  "mpris-proxy"
)

# shellcheck disable=SC2034
readonly -a SYSTEM_SERVICES=(
  "NetworkManager"
  "bluetooth"
  "udisks2"
  "fstrim.timer"
  "ufw"
)

readonly -a PACMAN_SERVICES=(
  "reflector.timer"
  "pacman-filesdb-refresh.timer"
  "paccache.timer"
)

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

enable_configured_services() {
  local -a failed_services=()
  local scope service error_msg

  for scope in user system; do
    local -n scope_services="${scope^^}_SERVICES"
    ((${#scope_services[@]} == 0)) && continue

    for service in "${scope_services[@]}"; do
      if enable_service "$service" "$scope"; then
        log INFO "${COLOR_GREEN}${service}${COLOR_RESET} enabled (${scope})"
        continue
      fi

      error_msg="$LAST_ERROR"
      if [[ "$error_msg" == "Unit not found:"* ]]; then
        log SKIP "$service ($scope) not available"
        continue
      fi

      failed_services+=("$service ($scope): $error_msg")
      log WARN "Failed to enable $service ($scope): $error_msg"
    done
  done

  ((${#failed_services[@]} > 0)) && log WARN "Some services failed to enable"

  case "${DISTRO_FAMILY,,}" in
  *arch*) ;;
  *)
    return 0
    ;;
  esac

  for service in "${PACMAN_SERVICES[@]}"; do
    if enable_service "$service" "system"; then
      log INFO "${COLOR_GREEN}${service}${COLOR_RESET} enabled"
      continue
    fi

    error_msg="$LAST_ERROR"
    if [[ "$error_msg" == "Unit not found:"* ]]; then
      log SKIP "$service not available"
      continue
    fi

    log WARN "Failed to enable $service: $error_msg"
  done

  return 0
}

configure_ufw() {
  if ! command_exists ufw; then
    log SKIP "UFW not installed"
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
    if sudo ufw default allow outgoing >/dev/null 2>&1; then
      log INFO "Set default policies"
    else
      log WARN "Failed to set outgoing policy"
    fi
  else
    log WARN "Failed to set incoming policy"
  fi

  return 0
}

disable_networkd_wait_online() {
  local service="systemd-networkd-wait-online.service"

  if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
    log SKIP "systemd-networkd-wait-online not present"
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
  if ! command_exists updatedb; then
    log SKIP "updatedb not available"
    return 0
  fi

  log INFO "Updating locate database"

  if sudo updatedb >/dev/null 2>&1; then
    log INFO "Locate database updated"
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
