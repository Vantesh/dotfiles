#!/usr/bin/env bash
# 04_login_manager.sh - Configure Ly display manager
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly LY_CONFIG_FILE="/etc/ly/config.ini"
readonly LY_SAVE_FILE="/etc/ly/save.ini"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

disable_conflicting_dms() {
  local skip_service="${1:-}"

  local other_dm_services=(
    sddm.service greetd.service gdm.service gdm3.service
    lightdm.service lxdm.service emptty.service
  )

  local svc
  local status

  for svc in "${other_dm_services[@]}"; do
    if [[ -n "$skip_service" ]] && [[ "$svc" == "$skip_service" ]]; then
      continue
    fi

    status=$(sudo systemctl is-enabled "$svc" 2>/dev/null || true)

    if [[ "$status" == "enabled" ]]; then
      if sudo systemctl disable "$svc" >/dev/null 2>&1; then
        log INFO "Disabled $svc"
        reload_systemd_daemon
        return 0
      else
        log WARN "Failed to disable $svc"
      fi
    fi
  done

  log SKIP "No conflicting display managers found"
}

configure_ly() {
  declare -A ly_config=(
    ["allow_empty_password"]="false"
    ["clear_password"]="true"
    ["bg"]="0"
    ["fg"]="8"
    ["bigclock"]="en"
    ["hide_key_hints"]="true"
    ["border_fg"]="8"
    ["path"]="null"
    ["sleep_cmd"]="systemctl suspend"
    ["session_log"]="/tmp/ly-session.log"
  )

  local key
  for key in "${!ly_config[@]}"; do
    if ! update_config "$LY_CONFIG_FILE" "$key" "${ly_config[$key]}"; then
      die "Failed to update ly config: $LAST_ERROR"
    fi
  done

  if ! write_system_config "$LY_SAVE_FILE" <<EOF; then
user=${USER}
session_index=2
EOF
    die "Failed to write ly save file: $LAST_ERROR"
  fi

  log INFO "Configured ly display manager"
}

disable_getty_tty2() {
  if sudo systemctl disable getty@tty2.service >/dev/null 2>&1; then
    log INFO "Disabled getty@tty2.service"
  else
    log WARN "Failed to disable getty@tty2.service"
  fi
}

setup_niri_session() {
  local session_file="/usr/share/wayland-sessions/niri-uwsm.desktop"

  if [[ -f "$session_file" ]]; then
    log SKIP "niri-uwsm session already configured"
    return 0
  fi

  if ! write_system_config "$session_file" <<'EOF'; then
[Desktop Entry]
Name=Niri (uwsm-managed)
Comment=A scrollable-tiling Wayland compositor
Exec=uwsm start -- niri.desktop
TryExec=uwsm
Type=Application
DesktopNames=niri
EOF
    die "Failed to create niri session file: $LAST_ERROR"
  fi

  log INFO "Created niri-uwsm session file"
}

main() {
  case "${DISTRO_FAMILY,,}" in
  *fedora* | *rhel*)
    print_box "Display Manager"
    log STEP "Display Manager Configuration"

    log SKIP "Fedora distro detected, skipping Ly configuration"

    if [[ "${COMPOSITOR,,}" == "niri" ]]; then
      setup_niri_session
    fi
    return 0
    ;;
  esac

  print_box "LY"
  log STEP "Ly Configuration"

  disable_conflicting_dms
  configure_ly

  if ! enable_service "ly.service" "system"; then
    die "Failed : $LAST_ERROR"
  else
    log INFO "${COLOR_GREEN}ly.service${COLOR_RESET} enabled"
  fi

  disable_getty_tty2

  if [[ "${COMPOSITOR,,}" == "niri" ]]; then
    setup_niri_session
  fi

  log INFO "Ly display manager configuration complete"
}

main "$@"
