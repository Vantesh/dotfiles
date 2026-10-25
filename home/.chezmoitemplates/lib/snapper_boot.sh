#!/usr/bin/env bash
# Existing snapshot boot integration, retained until Phase 6C.
set -euo pipefail
# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/common.sh"
# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/snapboot.sh"

readonly LIMINE_CONFIG="/etc/default/limine"
readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"

configure_limine_snapper() {
  if [[ ! -e "$LIMINE_CONFIG" ]]; then
    if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" ]] || [[ ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
      log ERROR "Limine templates not found"
      return 1
    fi

    if ! request_initramfs_rebuild; then
      log ERROR "Failed to queue Limine configuration rebuild: $LAST_ERROR"
      return 1
    fi

    if ! {
      cat "$LIMINE_ENTRY_TEMPLATE"
      printf '\n\n'
      cat "$LIMINE_SNAPPER_TEMPLATE"
    } | sudo tee "$LIMINE_CONFIG" >/dev/null 2>&1; then
      log ERROR "Failed to create Limine configuration"
      return 1
    fi

    log INFO "Created Limine configuration from templates"
  fi

  declare -A settings=(
    ["MAX_SNAPSHOT_ENTRIES"]="10"
    ["SNAPSHOT_FORMAT_CHOICE"]="8"
    ["TERMINAL"]="xdg-terminal-exec"
    ["TERMINAL_ARG"]="--title=FloatingTerm"
    ["QUIET_MODE"]="yes"
    ["ENABLE_LIMINE_FALLBACK"]="no"

  )

  if [[ -f /etc/kernel/cmdline ]]; then
    settings["ENABLE_UKI"]="yes"
  fi

  local key value current_value
  for key in "${!settings[@]}"; do
    value="${settings[$key]}"
    if ! current_value=$(get_limine_config_value "$key"); then
      log ERROR "Failed to read $key in Limine config"
      return 1
    fi
    [[ "$current_value" != "$value" ]] || continue

    if ! request_initramfs_rebuild; then
      log ERROR "Failed to queue Limine configuration rebuild: $LAST_ERROR"
      return 1
    fi

    if ! update_config "$LIMINE_CONFIG" "$key" "$value"; then
      log ERROR "Failed to update $key in Limine config: $LAST_ERROR"
      return 1
    fi
  done

  log INFO "Configured Limine snapper settings"
  return 0
}

add_mkinitcpio_overlay_hook() {
  local hooks overlay=btrfs-overlayfs
  if ! hooks=$(get_mkinitcpio_hooks); then
    log ERROR "Cannot read the effective mkinitcpio hooks"
    return 1
  fi
  [[ " $hooks " != *' systemd '* ]] || overlay=sd-btrfs-overlayfs
  if ! mkinitcpio_hook_exists "$overlay"; then
    log ERROR "Required mkinitcpio snapshot hook is unavailable: $overlay"
    return 1
  fi
  # shellcheck disable=SC2016
  local content='if [[ -n "${HOOKS:-}" && "${HOOKS@a}" != *a* ]]; then
  read -r -a HOOKS <<< "$HOOKS"
fi

_snapper_overlay=btrfs-overlayfs
if [[ " ${HOOKS[*]:-} " = *" systemd "* ]]; then
  _snapper_overlay=sd-btrfs-overlayfs
fi
if [[ " ${HOOKS[*]:-} " != *" $_snapper_overlay "* ]]; then
  if [[ "${HOOKS[-1]:-}" = strip ]]; then
    HOOKS[-1]="$_snapper_overlay"
    HOOKS+=(strip)
  else
    HOOKS+=("$_snapper_overlay")
  fi
fi
unset _snapper_overlay'

  if ! write_mkinitcpio_dropin "snapper.conf" "$content"; then
    log ERROR "Failed to configure mkinitcpio snapshot overlay: $LAST_ERROR"
    return 1
  fi


  log INFO "Configured mkinitcpio snapshot overlay drop-in"
  return 0
}

case "${1:-}" in
  prepare)
    validate_mkinitcpio_dropins || die "Cannot configure snapshot overlay hooks: $LAST_ERROR"
    configure_limine_snapper
    ;;
  overlay) add_mkinitcpio_overlay_hook ;;
  *) die "Expected prepare or overlay" ;;
esac
