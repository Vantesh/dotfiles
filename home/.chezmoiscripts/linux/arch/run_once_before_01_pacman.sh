#!/usr/bin/env bash
# 01_pacman.sh - Configure pacman
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly PACMAN_CONF="/etc/pacman.conf"
readonly PACCACHE_CONFIG="/etc/conf.d/pacman-contrib"
readonly HOOKS_DIR="/etc/pacman.d/hooks"

_ensure_pacman_contrib() {
  if pacman -Q "pacman-contrib" &>/dev/null; then
    return 0
  fi

  if ! sudo pacman -S --noconfirm "pacman-contrib" &>/dev/null; then
    LAST_ERROR="pacman-contrib installation failed"
    return 1
  fi

  return 0
}

_configure_pacman_options() {
  local pacman_conf="$1"
  local -a options=(
    "Color"
    "VerbosePkgLists"
    "ParallelDownloads"
  )

  for option in "${options[@]}"; do
    if grep -q "^#[[:space:]]*${option}" "$pacman_conf"; then
      sudo sed -i "s/^#[[:space:]]*${option}/${option}/" "$pacman_conf"
      log INFO "Enabled ${COLOR_CYAN}${option}${COLOR_RESET}"
    elif grep -q "^${option}" "$pacman_conf"; then
      log SKIP "${COLOR_CYAN}${option}${COLOR_RESET} already enabled"
    else
      log WARN "Option not found: $option"
    fi
  done
}

_add_ilovecandy() {
  local pacman_conf="$1"

  if grep -q "^ParallelDownloads" "$pacman_conf" && ! grep -q "^ILoveCandy" "$pacman_conf"; then
    sudo sed -i "/^ParallelDownloads/a ILoveCandy" "$pacman_conf"
    log INFO "Enabled ${COLOR_CYAN}ILoveCandy${COLOR_RESET}"
  elif grep -q "^ILoveCandy" "$pacman_conf"; then
    log SKIP "${COLOR_CYAN}ILoveCandy${COLOR_RESET} already enabled"
  fi
}

_configure_paccache() {
  if ! update_config "$PACCACHE_CONFIG" "PACCACHE_ARGS" "'-k2'"; then
    log WARN "Failed to configure paccache: $LAST_ERROR"
    return 1
  fi

  log INFO "Configured paccache (keep 2 versions)"
  return 0
}

_create_paccache_hooks() {
  if ! write_system_config "$HOOKS_DIR/00-paccache.hook" <<'EOF'; then
[Trigger]
Type = Package
Operation = Remove
Operation = Install
Operation = Upgrade
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk2
Depends = pacman-contrib
EOF
    log ERROR "Failed to create paccache cleanup hook: $LAST_ERROR"
    return 1
  fi
  log INFO "Created paccache cleanup hook"

  if ! write_system_config "$HOOKS_DIR/01-paccache-uninstalled.hook" <<'EOF'; then
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache for uninstalled packages...
When = PostTransaction
Exec = /usr/bin/paccache -ruk1
Depends = pacman-contrib
EOF
    log ERROR "Failed to create paccache uninstalled hook: $LAST_ERROR"
    return 1
  fi
  log INFO "Created paccache uninstalled hook"

  return 0
}

setup_pacman() {
  print_box "Pacman"
  log STEP "Configuring Pacman"

  if ! _ensure_pacman_contrib; then
    die "Failed to install dependencies: $LAST_ERROR"
  fi

  if create_backup "$PACMAN_CONF"; then
    log INFO "Created backup: ${PACMAN_CONF}.bak"
  else
    die "Failed to create backup: $LAST_ERROR"
  fi

  _configure_pacman_options "$PACMAN_CONF"
  _add_ilovecandy "$PACMAN_CONF"
  _configure_paccache

  if ! _create_paccache_hooks; then
    log WARN "Hooks may be incomplete"
  fi

}

main() {
  if ! setup_pacman; then
    die "Pacman setup failed"
  fi
}

main "$@"
