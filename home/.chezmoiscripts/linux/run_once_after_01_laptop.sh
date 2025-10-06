#!/usr/bin/env bash
# 01_laptop.sh - Configure laptop optimizations and hibernation
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

calculate_swap_size() {
  local ram_gb
  ram_gb=$(get_ram_size)

  local sqrt_ram
  sqrt_ram=$(awk "BEGIN {printf \"%.0f\", sqrt($ram_gb)}")

  local swap_gb=$((sqrt_ram + ram_gb))

  [[ $swap_gb -lt 2 ]] && swap_gb=2

  printf '%dG\n' "$swap_gb"
}

get_ram_size() {
  awk '/MemTotal/ {printf "%d", ($2 + 1048575) / 1048576}' /proc/meminfo
}

get_gpu_info() {
  lspci -nn 2>/dev/null | grep -Ei "VGA compatible controller|3D controller|Display controller" || printf ''
}

get_nvidia_pci_address() {
  local nvidia_pci

  nvidia_pci=$(lspci -Dnnd 10de: | awk '{print $1}' | head -n1)

  if [[ -z "$nvidia_pci" ]]; then
    nvidia_pci=$(lspci -D 2>/dev/null | grep -iE "NVIDIA.*(VGA|3D|Display)" | awk '{print $1}' | head -n1)
  fi

  printf '%s\n' "$nvidia_pci"
}

create_btrfs_swap() {
  local temp_mount
  local btrfs_root
  local uuid

  LAST_ERROR=""

  if ! btrfs_root=$(get_btrfs_root_device); then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to get btrfs root device: $error_msg"
    return 1
  fi

  if ! sudo btrfs subvolume list / 2>/dev/null | grep -q "$SWAP_SUBVOL"; then
    temp_mount=$(mktemp -d)

    if ! sudo mount "$btrfs_root" "$temp_mount" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs root device"
      rm -rf "$temp_mount"
      return 1
    fi

    if ! sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swap subvolume"
      sudo umount "$temp_mount" 2>/dev/null || true
      rm -rf "$temp_mount"
      return 1
    fi

    sudo umount "$temp_mount" 2>/dev/null || true
    rm -rf "$temp_mount"
    log INFO "Created btrfs swap subvolume"
  fi

  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    if ! sudo mkdir -p "$SWAP_MOUNT_POINT" 2>/dev/null; then
      LAST_ERROR="Failed to create swap mount point directory"
      return 1
    fi

    if ! sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_root" "$SWAP_MOUNT_POINT" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs swap subvolume"
      return 1
    fi

    log INFO "Mounted btrfs swap subvolume"
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    local swap_size
    swap_size=$(calculate_swap_size)

    if ! sudo btrfs filesystem mkswapfile --size "$swap_size" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swapfile"
      return 1
    fi

    log INFO "Created btrfs swapfile: $SWAP_FILE_PATH ($swap_size)"

    if ! uuid=$(sudo blkid -s UUID -o value "$btrfs_root" 2>/dev/null); then
      LAST_ERROR="Failed to get UUID of btrfs root device"
      return 1
    fi

    if ! add_fstab_entry "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0" "swap subvolume mount"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to add swap subvolume to fstab: $error_msg"
      return 1
    fi
  fi

  if ! sudo swapon --show 2>/dev/null | grep -q "$SWAP_FILE_PATH"; then
    if ! sudo swapon "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to activate swapfile"
      return 1
    fi

    log INFO "Activated btrfs swapfile"

    if ! add_fstab_entry "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to add swapfile to fstab: $error_msg"
      return 1
    fi
  fi

  return 0
}

get_swap_path() {
  sudo swapon --show=NAME --noheadings 2>/dev/null | awk '$1 !~ /\/dev\/zram/ {print; exit}'
}

setup_hibernation() {
  local swap_path
  local generator
  local bootloader
  local hibernation_params
  local resume_uuid
  local resume_offset
  local btrfs_root

  swap_path=$(get_swap_path)

  if [[ -z "$swap_path" ]]; then
    log INFO "No swap found, creating btrfs swapfile"

    if ! create_btrfs_swap; then
      die "Failed to create btrfs swap: $LAST_ERROR"
    fi

    swap_path=$(get_swap_path)

    if [[ -z "$swap_path" ]]; then
      log WARN "Swap still not detected after creation; resume parameters will be skipped"
      hibernation_params=("hibernate.compressor=lz4")
    fi
  fi

  hibernation_params=("hibernate.compressor=lz4")

  if [[ -n "$swap_path" ]]; then
    if [[ -b "$swap_path" ]]; then
      if ! resume_uuid=$(sudo blkid -s UUID -o value "$swap_path" 2>/dev/null); then
        die "Failed to get UUID for swap device: $swap_path"
      fi

      hibernation_params+=("resume=UUID=$resume_uuid")
    elif [[ -f "$swap_path" ]]; then
      if ! btrfs_root=$(get_btrfs_root_device); then
        die "Failed to get btrfs root device: $LAST_ERROR"
      fi

      if ! resume_uuid=$(sudo blkid -s UUID -o value "$btrfs_root" 2>/dev/null); then
        die "Failed to get UUID for btrfs root device"
      fi

      if ! resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$swap_path" 2>/dev/null); then
        die "Failed to get offset for swapfile: $swap_path"
      fi

      hibernation_params+=("resume=UUID=$resume_uuid" "resume_offset=$resume_offset")
    else
      log WARN "Swap path $swap_path is neither block device nor file"
    fi
  fi

  if ! generator=$(detect_initramfs_generator); then
    die "Failed to detect initramfs generator: $LAST_ERROR"
  fi

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  case "$bootloader" in
  grub)
    if ! update_grub_cmdline "${hibernation_params[@]}"; then
      die "Failed to update GRUB kernel command line: $LAST_ERROR"
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
        die "/proc/cmdline not readable; cannot create default Limine drop-in"
      fi
    fi

    if ! update_limine_cmdline "50-hibernation.conf" "${hibernation_params[@]}"; then
      die "Failed to write Limine hibernation config: $LAST_ERROR"
    fi
    log INFO "Updated Limine kernel parameters"
    ;;
  *)
    log WARN "Unsupported bootloader ($bootloader), skipping kernel parameter update"
    ;;
  esac

  case "$generator" in
  mkinitcpio)
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    local hooks

    if [[ ! -f "$mkinitcpio_conf" ]]; then
      die "mkinitcpio.conf not found"
    fi

    hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

    if [[ -n "$hooks" ]] && [[ "$hooks" != *" systemd "* ]]; then
      if [[ "$hooks" != *" resume "* ]]; then
        local new_hooks
        new_hooks=$(sed -E 's/(^| )filesystems( |$)/\1filesystems resume\2/' <<<"$hooks" | xargs)

        if [[ "$new_hooks" != "$hooks" ]]; then
          if ! sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" "$mkinitcpio_conf" 2>/dev/null; then
            die "Failed to update mkinitcpio HOOKS"
          fi

          log INFO "Updated mkinitcpio HOOKS (added resume)"

          if ! regenerate_initramfs; then
            die "Failed to regenerate initramfs: $LAST_ERROR"
          fi
          log INFO "Regenerated initramfs"
        fi
      fi
    fi
    ;;
  dracut)
    if ! add_dracut_module "resume"; then
      die "Failed to add dracut resume module: $LAST_ERROR"
    fi
    log INFO "Added dracut resume module"

    if ! regenerate_initramfs; then
      die "Failed to regenerate initramfs: $LAST_ERROR"
    fi
    log INFO "Regenerated initramfs"
    ;;
  unsupported)
    log WARN "No supported initramfs generator found, skipping initramfs configuration"
    ;;
  *)
    log WARN "Unknown initramfs generator ($generator), skipping initramfs configuration"
    ;;
  esac

  return 0
}

main() {
  local gpu_info
  local ram_size

  if is_laptop; then
    print_box "Laptop"
    log STEP "Laptop Optimizations"

    if command_exists powertop; then
      if sudo powertop --auto-tune >/dev/null 2>&1; then
        log INFO "Applied powertop auto-tune"
      else
        log WARN "Failed to apply powertop auto-tune"
      fi
    fi
  fi

  if ! check_btrfs; then
    log SKIP "Root filesystem is not btrfs, skipping hibernation setup"
    exit 0
  fi

  if ! is_laptop; then
    log SKIP "Not a laptop, skipping hibernation setup"
    exit 0
  fi

  if ! confirm "Set up hibernation?"; then
    log SKIP "Hibernation setup declined"
    exit 0
  fi

  log STEP "Hibernation Setup"

  local generator
  local bootloader

  if ! generator=$(detect_initramfs_generator); then
    die "Failed to detect initramfs generator: $LAST_ERROR"
  fi

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  if ! create_backup "/etc/fstab"; then
    die "Failed to backup /etc/fstab: $LAST_ERROR"
  fi

  if [[ "$generator" = "mkinitcpio" ]] && [[ -f /etc/mkinitcpio.conf ]]; then
    if ! create_backup "/etc/mkinitcpio.conf"; then
      die "Failed to backup /etc/mkinitcpio.conf: $LAST_ERROR"
    fi
  fi

  if [[ "$bootloader" = "grub" ]] && [[ -f /etc/default/grub ]]; then
    if ! create_backup "/etc/default/grub"; then
      die "Failed to backup /etc/default/grub: $LAST_ERROR"
    fi
  fi

  setup_hibernation

  if ! write_system_config "/etc/systemd/sleep.conf.d/hibernation.conf" <<'EOF'; then
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateMode=shutdown
HibernateDelaySec=50min
EOF
    die "Failed to write systemd sleep config: $LAST_ERROR"
  fi
  log INFO "Configured systemd sleep"

  if ! write_system_config "/etc/systemd/logind.conf.d/hibernation.conf" <<'EOF'; then
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=suspend-then-hibernate
EOF
    die "Failed to write systemd logind config: $LAST_ERROR"
  fi
  log INFO "Configured systemd logind"

  if ! write_system_config "/etc/tmpfiles.d/disable-usb-wake.conf" <<'EOF'; then
# Disable USB wakeup devices
#    Path                  Mode UID  GID  Age Argument
w    /proc/acpi/wakeup     -    -    -    -   XHC
EOF
    die "Failed to write USB wakeup config: $LAST_ERROR"
  fi
  log INFO "Configured USB wakeup disable"

  ram_size=$(get_ram_size)
  if [[ "$ram_size" -gt 30 ]]; then
    if ! write_system_config "/etc/tmpfiles.d/hibernation_image_size.conf" <<'EOF'; then
#    Path                   Mode UID  GID  Age Argument
w    /sys/power/image_size  -    -    -    -   0
EOF
      die "Failed to write hibernation image size config: $LAST_ERROR"
    fi
    log INFO "Configured hibernation image size"
  fi

  gpu_info=$(get_gpu_info)
  if [[ "$gpu_info" = *"NVIDIA Corporation"* ]]; then
    log INFO "Detected NVIDIA GPU, configuring power management"

    local services=(
      "nvidia-suspend-then-hibernate.service"
      "nvidia-hibernate.service"
      "nvidia-suspend.service"
      "nvidia-resume.service"
    )

    local svc
    for svc in "${services[@]}"; do
      if ! sudo systemctl --quiet is-enabled "$svc" 2>/dev/null; then
        if ! enable_service "$svc" "system"; then
          log WARN "Failed to enable $svc: $LAST_ERROR"
        fi
      fi
    done

    local nvidia_pci
    nvidia_pci=$(get_nvidia_pci_address)

    if [[ -n "$nvidia_pci" ]]; then
      if ! write_system_config "/etc/tmpfiles.d/nvidia_pm.conf" <<EOF; then
# NVIDIA power management
w /sys/bus/pci/devices/${nvidia_pci}/power/control - - - - auto
EOF
        die "Failed to write NVIDIA power management config: $LAST_ERROR"
      fi
      log INFO "Configured NVIDIA power management for $nvidia_pci"
    else
      log WARN "Failed to detect NVIDIA GPU PCI address"
    fi
  fi

  log INFO "Hibernation setup completed"
}

main "$@"
