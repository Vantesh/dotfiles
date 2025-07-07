#!/usr/bin/env bash

set -euo pipefail
# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/home/.chezmoiscripts/.00_helpers.sh"

# ------------------------------------------------------------------------------
# PACMAN CONFIGURATION
# ------------------------------------------------------------------------------
ask_for_sudo

enable_pacman_option() {
  local option="$1"
  local PACMAN_CONFIG="/etc/pacman.conf"

  if sudo grep -q "^\s*$option\s*$" "$PACMAN_CONFIG"; then
    log_info "${MAGENTA}$option${RESET} already enabled"
  elif sudo grep -q "^\s*#\s*$option" "$PACMAN_CONFIG"; then
    if sudo sed -i "s/^\s*#\s*${option}/${option}/" "$PACMAN_CONFIG"; then
      log_success "Enabled ${MAGENTA}$option${RESET}"
    else
      log_fail "Failed to enable ${MAGENTA}$option${RESET} in $PACMAN_CONFIG"
    fi
  elif [[ "$option" == "ILoveCandy" ]]; then
    if sudo sed -i "/^\s*Color/a $option" "$PACMAN_CONFIG"; then
      log_success "Enabled ${MAGENTA}$option${RESET}"
    else
      log_fail "Failed to add ${MAGENTA}$option${RESET} to $PACMAN_CONFIG"
    fi
  else
    log_warning "${MAGENTA}$option${RESET} not found in $PACMAN_CONFIG"
  fi
}

enable_pacman_option "Color"
enable_pacman_option "VerbosePkgLists"
enable_pacman_option "ILoveCandy"

pacman_hooks() {
  write_system_config "/etc/pacman.d/hooks/00-paccache.hook" "Paccache hook" <<EOF
[Trigger]
Type = Package
Operation = Remove
Operation = Install
Operation = Upgrade
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk1
Depends = pacman-contrib
EOF
  write_system_config "/etc/pacman.d/hooks/01-paccache-uninstalled.hook" "Paccache uninstalled hook" <<EOF
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache for uninstalled packages...
When = PostTransaction
Exec = /usr/bin/paccache -ruk0
Depends = pacman-contrib
EOF
}

# enable pacman services
enable_service "paccache.timer" "system"
enable_service "reflector.timer" "system"
