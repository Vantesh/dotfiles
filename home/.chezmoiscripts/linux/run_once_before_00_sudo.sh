#!/usr/bin/env bash

set -euo pipefail

# Source required libraries
LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.common.sh"

readonly SUDOERS_DIR="/etc/sudoers.d"
readonly FAILLOCK_CONF="/etc/security/faillock.conf"

_configure_sudo_timeout() {
  if ! write_system_config "$SUDOERS_DIR/timeout" "sudo timeout configuration" <<'EOF'; then
Defaults passwd_timeout=0
EOF
    log ERROR "Failed to configure sudo timeout: $LAST_ERROR"
    return 1
  fi

  log INFO "updated $LAST_SUCCESS"
  return 0
}

_configure_sudo_retries() {
  if ! write_system_config "$SUDOERS_DIR/passwd_tries" "sudo retry configuration" <<'EOF'; then
Defaults passwd_tries=10
EOF
    log ERROR "Failed to configure sudo retries: $LAST_ERROR"
    return 1
  fi

  log INFO "updated $LAST_SUCCESS"
  return 0
}

_configure_faillock() {

  local -A faillock_settings=(
    [deny]="20"           # Lock after 20 failed attempts
    [unlock_time]="120"   # Unlock after 2 minutes
    [fail_interval]="900" # Count failures within 15 minutes
  )

  for key in "${!faillock_settings[@]}"; do
    local value="${faillock_settings[$key]}"

    if ! update_config "$FAILLOCK_CONF" "$key" "$value"; then
      log ERROR "Failed to update faillock setting: $key=$value ($LAST_ERROR)"
      return 1
    fi

    log INFO "updated faillock: $key=$value"
  done

  return 0
}

setup_sudo() {
  log STEP "Configuring sudo and authentication security"

  if ! _configure_sudo_timeout; then
    die "Failed to configure sudo timeout"
  fi

  if ! _configure_sudo_retries; then
    die "Failed to configure sudo retries"
  fi

  if ! _configure_faillock; then
    die "Failed to configure faillock"
  fi
}

main() {
  if ! setup_sudo; then
    die "Sudo setup failed"
  fi
}

main "$@"
