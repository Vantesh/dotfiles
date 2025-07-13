#!/bin/bash

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers.sh"

configure_sudo_timeout() {
  printc -n cyan "Disabling sudo password prompt timeout... "

  local sudoers_config="/etc/sudoers.d/timeout"

  if echo "Defaults passwd_timeout=0" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_sudo_insults() {
  printc -n cyan "Enabling sudo insults... "

  local sudoers_config="/etc/sudoers.d/insults"

  if echo "Defaults insults" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_sudo_pwfeedback() {
  printc -n cyan "Enabling sudo password feedback... "

  local sudoers_config="/etc/sudoers.d/pwfeedback"

  if echo "Defaults pwfeedback" | sudo tee "$sudoers_config" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_faillock() {
  declare -A faillock_config=(
    [deny]="10"
    [unlock_time]="300"
    [fail_interval]="900"
  )
  printc -n cyan "Configuring faillock settings... "
  local success=true
  for key in "${!faillock_config[@]}"; do
    if ! update_config "/etc/security/faillock.conf" "$key" "${faillock_config[$key]}"; then
      success=false
      break
    fi
  done
  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# Main execution
ask_for_sudo
initialize_environment
printc_box "SUDO" "Configuring QOL sudo settings"
configure_sudo_timeout
configure_sudo_insults
configure_sudo_pwfeedback
configure_faillock
