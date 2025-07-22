#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers"

readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly HOOKS="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems"

# ram size in GB
ram_size=$(awk '/MemTotal/ {printf "%d\n", int(($2 + 1024 * 1024 - 1) / (1024 * 1024)) + ((($2 + 1024 * 1024 - 1) % (1024 * 1024)) > 0 ? 1 : 0)}' /proc/meminfo)

#swap size in GB
swap_size() {
  # square root of ram size in GB (ubuntu uses this formula)
  sqrt_ram_size=$(awk "BEGIN {printf \"%.0f\", sqrt($ram_size)}")
  swap_size=$((sqrt_ram_size + ram_size))
  [[ $swap_size -lt 2 ]] && swap_size=2 # minimum swap size is 2GB
  echo "${swap_size}G"

}

create_btrfs_swap_subvolume() {
  if ! sudo btrfs subvolume list / | grep -q "$SWAP_SUBVOL"; then
    temp_mount_point=$(mktemp -d)
    if sudo mount "$(get_btrfs_root_device)" "$temp_mount_point" >/dev/null; then
      if sudo btrfs subvolume create "$temp_mount_point/$SWAP_SUBVOL" >/dev/null; then
        print_info "Btrfs swap subvolume created"
        sudo umount "$temp_mount_point"
        rm -rf "$temp_mount_point"
      else
        print_error "Failed to create Btrfs swap subvolume"
      fi
    else
      print_error "Failed to mount Btrfs root device"
    fi
    sudo umount "$temp_mount_point" 2>/dev/null || true
  else
    print_info "Btrfs swap subvolume already exists"
  fi

  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    if sudo mkdir -p "$SWAP_MOUNT_POINT"; then
      if sudo mount -o subvol="$SWAP_SUBVOL" "$(get_btrfs_root_device)" "$SWAP_MOUNT_POINT" >/dev/null; then
        print_info "Btrfs swap subvolume mounted"
      else
        print_error "Failed to mount Btrfs swap subvolume"
      fi
    fi
  else
    print_info "Btrfs swap subvolume already mounted at $SWAP_MOUNT_POINT"
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    if sudo btrfs filesystem mkswapfile --size "$(swap_size)" --uuid clear "$SWAP_FILE_PATH" >/dev/null; then
      print_info "Btrfs swap file created at $SWAP_FILE_PATH"
      uuid=$(sudo blkid -s UUID -o value "$(get_btrfs_root_device)") || {
        print_error "Failed to get UUID of Btrfs root device"
        return 1
      }

      add_entry_to_fstab "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0" "swap subvolume mount"

    else
      print_error "Failed to create Btrfs swap file"
    fi
  else
    print_info "Btrfs swap file already exists at $SWAP_FILE_PATH"
  fi

  if ! sudo swapon --show | grep -q "$SWAP_FILE_PATH"; then
    if sudo swapon "$SWAP_FILE_PATH" >/dev/null; then
      print_info "Btrfs swap file activated"
      add_entry_to_fstab "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"
    else
      print_error "Failed to activate Btrfs swap file"
    fi
  else
    print_info "Btrfs swap file already activated"
  fi

}

# ===========================================================================================
# HIBERNATION SETUP
# ===========================================================================================

setup_hibernation() {
  swap_path=$(sudo swapon --show --noheadings | awk '{print $1}' | grep -v '^/dev/zram' | head -n1)

  if [[ -z "$swap_path" ]]; then
    print_info "No swap file found, creating Btrfs swap subvolume and file"
    create_btrfs_swap_subvolume
  fi

  hibernation_params=(hibernate.compressor=lz4)

  if [[ -b "$swap_path" ]]; then
    resume_uuid=$(sudo blkid -s UUID -o value "$swap_path")
    if [[ -n "$resume_uuid" ]]; then
      hibernation_params+=("resume=UUID=$resume_uuid")
    else
      print_error "Failed to get UUID for swap device: $swap_path"
    fi
  fi

  if [[ -f $swap_path ]]; then
    resume_uuid=$(sudo blkid -s UUID -o value "$(get_btrfs_root_device)")
    resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$swap_path")
    if [[ -n "$resume_uuid" && -n "$resume_offset" ]]; then
      hibernation_params+=("resume=UUID=$resume_uuid" "resume_offset=$resume_offset")
    else
      print_error "Failed to get UUID or offset for swap file: $swap_path"
    fi
  fi

  update_kernel_cmdline "${hibernation_params[@]}" || {
    print_error "Failed to update kernel command line for hibernation"
    return 1
  }

}

if is_btrfs && is_laptop && confirm "Do you want to set up hibernation? "; then
  print_box "smslant" "Hibernation"
  print_step "Setting up hibernation with Btrfs swap subvolume and file"

  create_backup "$MKINIT_CONF"
  create_backup "/etc/fstab"

  if [[ $(detect_bootloader) == "grub" ]]; then
    create_backup "/etc/default/grub"
  elif [[ $(detect_bootloader) == "limine" ]]; then
    create_backup "/etc/kernel/cmdline"
  fi
  setup_hibernation

  if sudo sed -i -E "s/^HOOKS=(.*)/HOOKS=(${HOOKS})/" "$MKINIT_CONF"; then
    print_info "Updated mkinitcpio hooks"
    regenerate_initramfs
  else
    print_error "Failed to update mkinitcpio hooks"
  fi

  write_system_config "/etc/systemd/sleep.conf.d/hibernation.conf" "systemd sleep config" <<'EOF'
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateMode=shutdown
HibernateDelaySec=50min
EOF

  write_system_config "/etc/systemd/logind.conf.d/hibernation.conf" "systemd logind hibernation config" <<'EOF'
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=suspend-then-hibernate
EOF

  write_system_config "/etc/tmpfiles.d/disable-usb-wake.conf" "disable USB wakeup config" <<'EOF'
# Disable USB wakeup devices
#    Path                  Mode UID  GID  Age Argument
w    /proc/acpi/wakeup     -    -    -    -   XHC
EOF

  if [[ $ram_size -gt 30 ]]; then
    write_system_config "/etc/tmpfiles.d/hibernation_image_size.conf" "hibernation image size config" <<'EOF'
#    Path                   Mode UID  GID  Age Argument
w    /sys/power/image_size  -    -    -    -   0
EOF
  fi

  if sudo sed -i -E '/btrfs/ { s/\brelatime\b/noatime/g; s/\bdefaults\b/defaults,noatime/g; s/(,noatime){2,}/,noatime/g; s/,+/,/g; }' /etc/fstab; then
    print_info "Updated /etc/fstab with noatime for Btrfs"
    reload_systemd_daemon
  else
    print_error "Failed to update /etc/fstab with noatime for Btrfs"
  fi
fi
