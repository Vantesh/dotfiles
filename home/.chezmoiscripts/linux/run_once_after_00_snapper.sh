#!/usr/bin/env bash
# 00_snapper.sh - Set up snapper for btrfs snapshots
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-package_manager.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly LIMINE_CONFIG="/etc/default/limine"
readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"
readonly MKINITCPIO_CONF="/etc/mkinitcpio.conf"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

setup_snapper_packages() {
  local -a packages=(
    snapper
    btrfs-assistant
    btrfs-progs
    inotify-tools
  )

  if command_exists pacman; then
    packages+=(
      snap-pac
    )
  elif command_exists dnf; then
    packages+=(
      python3-dnf-plugin-snapper
      libdnf5-plugin-actions
    )
  fi

  local bootloader
  if ! bootloader=$(detect_bootloader); then
    log ERROR "Failed to detect bootloader: $LAST_ERROR"
    return 1
  fi

  local generator
  if ! generator=$(detect_initramfs_generator); then
    log ERROR "Failed to detect initramfs generator: $LAST_ERROR"
    return 1
  fi

  case "$bootloader" in
  limine)
    case "$generator" in
    mkinitcpio)
      packages+=(
        limine-mkinitcpio-hook
      )
      ;;
    dracut)
      packages+=(
        limine-dracut-support
      )
      ;;
    *)
      log WARN "Unknown initramfs generator ($generator) for Limine"
      ;;
    esac

    packages+=(
      limine-snapper-sync
    )
    ;;
  grub)
    packages+=(
      grub-btrfs
    )
    ;;
  esac

  local package
  for package in "${packages[@]}"; do
    if ! install_package "$package"; then
      log ERROR "Failed to install $package: $LAST_ERROR"
      return 1
    fi
  done

  return 0
}

enable_snapper_services() {
  local -a services=(
    snapper-cleanup.timer
  )

  local bootloader
  if ! bootloader=$(detect_bootloader); then
    log ERROR "Failed to detect bootloader: $LAST_ERROR"
    return 1
  fi

  case "$bootloader" in
  limine)
    services+=(
      limine-snapper-sync.service
    )
    ;;
  grub)
    if systemctl list-unit-files grub-btrfsd.service >/dev/null 2>&1; then
      services+=(
        grub-btrfsd.service
      )
    elif systemctl list-unit-files grub-btrfs.service >/dev/null 2>&1; then
      services+=(
        grub-btrfs.service
      )
    else
      log WARN "grub-btrfs unit not found (grub-btrfsd.service or grub-btrfs.service)"
    fi
    ;;
  esac

  local service
  for service in "${services[@]}"; do
    if ! enable_service "$service"; then
      log WARN "Failed to enable $service: $LAST_ERROR"
    else
      log INFO "${COLOR_GREEN}${service}${COLOR_RESET} enabled"
    fi
  done

  return 0
}

configure_limine_snapper() {
  if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" ]] || [[ ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
    log ERROR "Limine templates not found"
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

  declare -A settings=(
    ["MAX_SNAPSHOT_ENTRIES"]="15"
    ["TERMINAL"]="xdg-terminal-exec"
    ["TERMINAL_ARG"]=""
    ["SNAPSHOT_FORMAT_CHOICE"]="0"
    ["QUIET_MODE"]="yes"
    ["ENABLE_LIMINE_FALLBACK"]="yes"
  )

  if [[ -f /etc/kernel/cmdline ]]; then
    settings["ENABLE_UKI"]="yes"
  fi

  local key value
  for key in "${!settings[@]}"; do
    value="${settings[$key]}"

    if ! update_config "$LIMINE_CONFIG" "$key" "$value"; then
      log ERROR "Failed to update $key in Limine config: $LAST_ERROR"
      return 1
    fi
  done

  log INFO "Configured Limine snapper settings"
  return 0
}

configure_snapper() {
  declare -A settings=(
    ["NUMBER_CLEANUP"]="yes"
    ["NUMBER_LIMIT"]="20"
    ["TIMELINE_CREATE"]="no"
    ["TIMELINE_CLEANUP"]="yes"
    ["TIMELINE_MIN_AGE"]="1800"
    ["TIMELINE_LIMIT_HOURLY"]="5"
    ["TIMELINE_LIMIT_DAILY"]="7"
    ["TIMELINE_LIMIT_WEEKLY"]="0"
    ["TIMELINE_LIMIT_MONTHLY"]="0"
    ["TIMELINE_LIMIT_YEARLY"]="0"
    ["EMPTY_PRE_POST_CLEANUP"]="yes"
    ["EMPTY_PRE_POST_MIN_AGE"]="1800"
  )

  local key value
  for key in "${!settings[@]}"; do
    value="${settings[$key]}"

    if ! set_snapper_config_value "root" "$key" "$value"; then
      log ERROR "Failed to set snapper config $key: $LAST_ERROR"
      return 1
    fi
  done

  log INFO "Configured snapper settings"
  return 0
}

add_mkinitcpio_overlay_hook() {
  local generator
  if ! generator=$(detect_initramfs_generator); then
    log ERROR "Failed to detect initramfs generator: $LAST_ERROR"
    return 1
  fi

  if [[ "$generator" != "mkinitcpio" ]]; then
    log WARN "Initramfs generator is $generator, skipping mkinitcpio overlay hook"
    return 0
  fi

  local bootloader
  if ! bootloader=$(detect_bootloader); then
    log ERROR "Failed to detect bootloader: $LAST_ERROR"
    return 1
  fi

  local hook
  case "$bootloader" in
  grub)
    hook="grub-btrfs-overlayfs"
    ;;
  limine)
    hook="btrfs-overlayfs"
    ;;
  *)
    log WARN "No overlay hook needed for bootloader: $bootloader"
    return 0
    ;;
  esac

  local current_hooks
  current_hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$MKINITCPIO_CONF" 2>/dev/null | head -n1)

  if [[ "$current_hooks" == *" systemd "* ]]; then
    log WARN "systemd hook detected, skipping overlay hook (incompatible)"
    return 0
  fi

  local hook_exists=false
  if grep -q "^HOOKS=.*$hook" /etc/mkinitcpio.conf; then
    hook_exists=true
  fi

  if ! add_mkinitcpio_hook "$hook"; then
    log ERROR "Failed to add mkinitcpio hook: $LAST_ERROR"
    return 1
  fi

  if [[ "$hook_exists" == "false" ]]; then
    log INFO "Added $hook to mkinitcpio HOOKS"

    if ! regenerate_initramfs; then
      log ERROR "Failed to regenerate initramfs: $LAST_ERROR"
      return 1
    fi
    log INFO "Regenerated initramfs"
  else
    log SKIP "mkinitcpio hook $hook already present"
  fi

  return 0
}

optimize_btrfs_fstab() {
  if ! grep -q 'btrfs.*relatime' /etc/fstab; then
    log SKIP "Btrfs fstab already optimized or not using relatime"
    return 0
  fi

  if ! create_backup "/etc/fstab"; then
    LAST_ERROR="Failed to backup fstab: $LAST_ERROR"
    return 1
  fi

  if ! sudo sed -i -E '/btrfs/ { s/\brelatime\b/noatime/g; s/\bdefaults\b/defaults,noatime/g; s/(,noatime){2,}/,noatime/g; s/,+/,/g; }' /etc/fstab; then
    local error_msg="Failed to update fstab with noatime"
    if ! restore_backup "/etc/fstab"; then
      LAST_ERROR="$error_msg and restore backup failed: $LAST_ERROR"
    else
      LAST_ERROR="$error_msg (backup restored)"
    fi
    return 1
  fi

  if ! reload_systemd_daemon; then
    local error_msg="$LAST_ERROR"
    if ! restore_backup "/etc/fstab"; then
      LAST_ERROR="Failed to reload systemd daemon: $error_msg (backup restore also failed)"
    else
      LAST_ERROR="Failed to reload systemd daemon: $error_msg (backup restored)"
    fi
    return 1
  fi

  log INFO "Optimized btrfs mounts in fstab (relatime → noatime)"
  return 0
}

configure_dnf_snapper_plugin() {
  if ! command_exists dnf; then
    return 0
  fi

  local actions_file="/etc/dnf/libdnf5-plugins/actions.d/snapper.actions"

  if [[ -f "$actions_file" ]]; then
    log SKIP "DNF snapper actions already configured"
    return 0
  fi

  if ! write_system_config "$actions_file" <<'EOF'; then
# /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.cmd=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"
# Creates pre snapshot before the transaction and stores the snapshot number in the "tmp.snapper_pre_number"  variable.
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -c\ number\ -t\ pre\ -p\ -d\ '${tmp.cmd}')"

# If the variable "tmp.snapper_pre_number" exists, it creates post snapshot after the transaction and removes the variable "tmp.snapper_pre_number".
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -c\ number\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -d\ "${tmp.cmd}"\ ;\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.cmd
EOF
    log ERROR "Failed to create DNF snapper actions: $LAST_ERROR"
    return 1
  fi

  log INFO "Configured DNF snapper plugin"
  return 0
}

main() {
  local os_id
  local os_name

  if os_id=$(get_os_id) && os_name=$(get_os_name); then
    case "$os_id" in
    garuda | cachyos)
      log SKIP "$os_name already has snapper pre-configured"
      return 0
      ;;
    esac
  fi

  if ! check_btrfs; then
    log WARN "Root filesystem is not btrfs, skipping snapper setup"
    return 0
  fi

  print_box "Snapper"

  if ! confirm "Set up Snapper for btrfs snapshots?"; then
    log SKIP "Snapper setup cancelled by user"
    return 0
  fi

  log STEP "Configuring Snapper"

  if ! setup_snapper_packages; then
    die "Failed to install snapper packages"
  fi

  if ! configure_dnf_snapper_plugin; then
    log WARN "Failed to configure DNF snapper plugin: $LAST_ERROR"
  fi

  if ! enable_snapper_services; then
    log WARN "Some services failed to enable, continuing anyway"
  fi

  local bootloader
  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  if [[ "$bootloader" = "limine" ]]; then
    if ! configure_limine_snapper; then
      die "Failed to configure Limine snapper integration"
    fi
  fi

  if ! configure_snapper; then
    die "Failed to configure snapper"
  fi

  if ! add_mkinitcpio_overlay_hook; then
    log WARN "Failed to add mkinitcpio overlay hook, snapshots may not be bootable"
  fi

  if ! optimize_btrfs_fstab; then
    log WARN "Failed to optimize btrfs fstab: $LAST_ERROR"
  fi

  log INFO "Snapper configuration complete"
}

main "$@"
