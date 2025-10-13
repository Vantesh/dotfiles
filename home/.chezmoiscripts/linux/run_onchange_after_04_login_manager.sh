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
  local -r other_dms=(sddm greetd gdm gdm3 lightdm lxdm emptty)

  local svc status
  for svc in "${other_dms[@]}"; do
    status=$(sudo systemctl is-enabled "${svc}.service" 2>/dev/null || true)

    if [[ "$status" == "enabled" ]]; then
      if sudo systemctl disable "${svc}.service" >/dev/null 2>&1; then
        log INFO "Disabled ${svc}.service"
        reload_systemd_daemon
        return 0
      fi
      log WARN "Failed to disable ${svc}.service"
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

  write_system_config "$LY_SAVE_FILE" <<EOF || die "Failed to write ly save file: $LAST_ERROR"
user=${USER}
session_index=2
EOF

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
  local -r session_file="/usr/share/wayland-sessions/niri-uwsm.desktop"

  if [[ -f "$session_file" ]]; then
    log SKIP "niri-uwsm session already configured"
    return 0
  fi

  write_system_config "$session_file" <<'EOF' || die "Failed to create niri session file: $LAST_ERROR"
[Desktop Entry]
Name=Niri (uwsm-managed)
Comment=A scrollable-tiling Wayland compositor
Exec=uwsm start -- niri.desktop
TryExec=uwsm
Type=Application
DesktopNames=niri
EOF

  log INFO "Created niri-uwsm session file"
}

main() {
  if [[ "${DISTRO_FAMILY,,}" == *fedora* ]]; then
    print_box "Display Manager"
    log STEP "Display Manager Configuration"
    log SKIP "Fedora distro detected, skipping Ly configuration"

    if [[ "${COMPOSITOR,,}" == "niri" ]]; then
      setup_niri_session
    fi
    return 0
  fi

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
