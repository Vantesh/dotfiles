#!/usr/bin/env bash
# 02_plymouth.sh - Configure Plymouth boot splash
# Exit codes: 0 (success), 1 (failure), 2 (already configured)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly QUIET_BOOT_PARAMS="quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

add_plymouth_hook() {
  local mkinitcpio_conf="/etc/mkinitcpio.conf"
  local current_hooks
  local new_hooks

  LAST_ERROR=""

  if [[ ! -f "$mkinitcpio_conf" ]]; then
    LAST_ERROR="mkinitcpio.conf not found"
    return 1
  fi

  current_hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

  if [[ -z "$current_hooks" ]]; then
    LAST_ERROR="Failed to parse HOOKS from mkinitcpio.conf"
    return 1
  fi

  if [[ "$current_hooks" == *"plymouth"* ]]; then
    LAST_ERROR="Plymouth hook already present"
    return 2
  fi

  if [[ "$current_hooks" == *"base systemd"* ]]; then
    new_hooks=$(sed -E 's/(base systemd)/\1 plymouth/' <<<"$current_hooks")
  elif [[ "$current_hooks" == *"base udev"* ]]; then
    new_hooks=$(sed -E 's/(base udev)/\1 plymouth/' <<<"$current_hooks")
  else
    LAST_ERROR="Could not find 'base systemd' or 'base udev' in HOOKS"
    return 1
  fi

  if [[ "$new_hooks" = "$current_hooks" ]]; then
    LAST_ERROR="Failed to modify HOOKS"
    return 1
  fi

  if ! sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" "$mkinitcpio_conf" 2>/dev/null; then
    LAST_ERROR="Failed to update mkinitcpio.conf"
    return 1
  fi

  return 0
}

configure_plymouth_service() {
  local service_dir="/etc/systemd/system/plymouth-quit.service.d"
  local service_conf="$service_dir/wait-for-graphical.conf"

  LAST_ERROR=""

  if [[ -f "$service_conf" ]]; then
    return 0
  fi

  if ! write_system_config "$service_conf" <<'EOF'; then
[Unit]
After=multi-user.target
EOF
    LAST_ERROR="Failed to write plymouth service config"
    return 1
  fi

  return 0
}

mask_plymouth_quit_wait() {
  LAST_ERROR=""

  if sudo systemctl is-enabled plymouth-quit-wait.service 2>/dev/null | grep -q "masked"; then
    return 0
  fi

  if ! sudo systemctl mask plymouth-quit-wait.service >/dev/null 2>&1; then
    LAST_ERROR="Failed to mask plymouth-quit-wait.service"
    return 1
  fi

  if ! reload_systemd_daemon; then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to reload systemd daemon: $error_msg"
    return 1
  fi

  return 0
}

update_bootloader_params() {
  local bootloader
  local generator

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  if ! generator=$(detect_initramfs_generator); then
    die "Failed to detect initramfs generator: $LAST_ERROR"
  fi

  case "$bootloader" in
  grub)
    if ! update_grub_cmdline "$QUIET_BOOT_PARAMS"; then
      die "Failed to update GRUB kernel parameters: $LAST_ERROR"
    fi
    log INFO "Updated GRUB kernel parameters"
    ;;
  limine)
    if [[ ! -f /etc/limine-entry-tool.d/01-default.conf ]]; then
      if [[ -r /proc/cmdline ]]; then
        local default_params
        default_params=$(cat /proc/cmdline)

        if ! update_limine_cmdline "01-default.conf" "$default_params"; then
          die "Failed to create default Limine config: $LAST_ERROR"
        fi
      else
        log WARN "/proc/cmdline not readable; cannot create default Limine drop-in"
      fi
    fi

    if ! update_limine_cmdline "20-quiet-boot.conf" "$QUIET_BOOT_PARAMS"; then
      die "Failed to write Limine quiet boot config: $LAST_ERROR"
    fi
    log INFO "Updated Limine kernel parameters"
    ;;
  *)
    log WARN "Unsupported bootloader ($bootloader), skipping kernel parameter update"
    ;;
  esac
}

main() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "${ID:-}" in
    fedora | cachyos | garuda)
      log SKIP "$NAME already has plymouth pre-configured"
      return 0
      ;;
    esac
  fi

  local generator
  local needs_initramfs_regen=false

  print_box "Plymouth"
  log STEP "Plymouth Configuration"

  if ! generator=$(detect_initramfs_generator); then
    die "Failed to detect initramfs generator: $LAST_ERROR"
  fi

  if [[ "$generator" = "mkinitcpio" ]]; then
    local mkinitcpio_conf="/etc/mkinitcpio.conf"

    if ! create_backup "$mkinitcpio_conf"; then
      die "Failed to backup mkinitcpio.conf: $LAST_ERROR"
    fi

    local hook_result=0
    add_plymouth_hook || hook_result=$?

    case $hook_result in
    0)
      log INFO "Added plymouth hook to mkinitcpio"
      needs_initramfs_regen=true
      ;;
    2)
      log SKIP "Plymouth hook already configured"
      ;;
    *)
      if [[ "$LAST_ERROR" == "Could not find 'base systemd' or 'base udev' in HOOKS" ]]; then
        log WARN "$LAST_ERROR, skipping plymouth hook"
      else
        die "Failed to add plymouth hook: $LAST_ERROR"
      fi
      ;;
    esac
  elif [[ "$generator" = "dracut" ]]; then
    local dracut_result=0
    add_dracut_module "plymouth" || dracut_result=$?

    case $dracut_result in
    0)
      log INFO "Added plymouth dracut module"
      needs_initramfs_regen=true
      ;;
    2)
      log SKIP "Plymouth dracut module already configured"
      ;;
    *)
      die "Failed to add plymouth dracut module: $LAST_ERROR"
      ;;
    esac
  fi

  update_bootloader_params

  if ! configure_plymouth_service; then
    die "Failed to configure plymouth service: $LAST_ERROR"
  fi
  log INFO "Configured plymouth service"

  if ! mask_plymouth_quit_wait; then
    log WARN "Failed to mask plymouth-quit-wait service: $LAST_ERROR"
  else
    log INFO "Masked plymouth-quit-wait service"
  fi

  if [[ "$needs_initramfs_regen" = true ]]; then
    log INFO "Regenerating initramfs (this may take a moment)..."
    if ! regenerate_initramfs; then
      die "Failed to regenerate initramfs: $LAST_ERROR"
    fi
    log INFO "Regenerated initramfs"
  else
    log SKIP "No initramfs changes, skipping regeneration"
  fi

  log INFO "Plymouth configuration complete"
}

main "$@"
