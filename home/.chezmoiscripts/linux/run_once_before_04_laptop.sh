#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"

#=============================================================================
# LAPTOP
#=============================================================================

if is_laptop; then
  print_box "smslant" "Laptop"
  print_step "Setting up laptop tweaks"

  write_system_config "$TOUCHPAD_RULE_FILE" "touchpad udev rule" <<'EOF'
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF

  reload_udev_rules || {
    print_error "Failed to reload udev rules"
  }

  enable_service "libinput-gestures.service" "user"

  print_info "Setting up powertop"
  if sudo powertop --auto-tune >/dev/null 2>&1; then
    print_info "Powertop auto-tune applied successfully"
  else
    print_warning "Failed to apply Powertop auto-tune"
  fi
fi

#=============================================================================
# HIBERNATION SETUP
#=============================================================================

readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly HOOKS="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems"

gpu_info=$(lspci -nn | grep -Ei "VGA compatible controller|3D controller|Display controller")

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
        sudo umount "$temp_mount_point"
        rm -rf "$temp_mount_point"
      else
        print_error "Failed to create Btrfs swap subvolume"
      fi
    else
      print_error "Failed to mount Btrfs root device"
    fi
    sudo umount "$temp_mount_point" 2>/dev/null || true
  fi

  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    if sudo mkdir -p "$SWAP_MOUNT_POINT"; then
      if sudo mount -o subvol="$SWAP_SUBVOL" "$(get_btrfs_root_device)" "$SWAP_MOUNT_POINT" >/dev/null; then
        print_info "Btrfs swap subvolume mounted"
      else
        print_error "Failed to mount Btrfs swap subvolume"
      fi
    fi
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    if sudo btrfs filesystem mkswapfile --size "$(swap_size)" --uuid clear "$SWAP_FILE_PATH" >/dev/null; then
      print_info "Btrfs swap file created at $SWAP_FILE_PATH"
      uuid=$(sudo blkid -s UUID -o value "$(get_btrfs_root_device)") || {
        print_error "Failed to get UUID of Btrfs root device"
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

get_swap_path() {
  # Return first non-zram active swap (device or file)
  sudo swapon --show=NAME --noheadings 2>/dev/null | awk '$1 !~ /\/dev\/zram/ {print; exit}'
}

setup_hibernation() {
  swap_path=$(get_swap_path)

  if [[ -z "$swap_path" ]]; then
    print_info "No swap found, creating Btrfs swapfile"
    create_btrfs_swap_subvolume
    swap_path=$(get_swap_path)
    [[ -z "$swap_path" ]] && print_warning "Swap still not detected after creation; resume parameters will be skipped."
  fi

  hibernation_params=(hibernate.compressor=lz4)

  if [[ -n "$swap_path" ]]; then
    if [[ -b "$swap_path" ]]; then
      # Direct block device swap (e.g. partition)
      resume_uuid=$(sudo blkid -s UUID -o value "$swap_path")
      if [[ -n "$resume_uuid" ]]; then
        hibernation_params+=("resume=UUID=$resume_uuid")
      else
        print_error "Failed to get UUID for swap device: $swap_path"
      fi
    elif [[ -f "$swap_path" ]]; then
      # Swap file (Btrfs)
      resume_uuid=$(sudo blkid -s UUID -o value "$(get_btrfs_root_device)")
      resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$swap_path")
      if [[ -n "$resume_uuid" && -n "$resume_offset" ]]; then
        hibernation_params+=("resume=UUID=$resume_uuid" "resume_offset=$resume_offset")
      else
        print_error "Failed to get UUID or offset for swap file: $swap_path"
      fi
    else
      print_warning "Swap path $swap_path exists but is neither block device nor regular file"
    fi
  fi

  case "$(detect_bootloader)" in
  grub)
    update_grub_cmdline "${hibernation_params[@]}" || {
      print_error "Failed to update GRUB kernel command line for hibernation"

    }
    ;;
  limine)
    # For Limine, create 01-default.conf once from /proc/cmdline if missing
    if [[ $(detect_bootloader) == "limine" ]]; then
      if [[ ! -f /etc/limine-entry-tool.d/01-default.conf ]]; then
        if [[ -r /proc/cmdline ]]; then
          default_params=$(cat /proc/cmdline)
          update_limine_cmdline "01-default.conf" "$default_params"
        else
          print_error "/proc/cmdline not readable; cannot create default Limine drop-in"
        fi
      fi
    fi

    # add hibernation params in a dedicated drop-in file
    update_limine_cmdline "50-hibernation.conf" "${hibernation_params[@]}" || {
      print_error "Failed to write Limine drop-in for hibernation"

    }
    ;;
  *)
    print_warning "Unsupported bootloader, skipping kernel parameter update."
    ;;
  esac

}

# ===========================================================================================
# MAIN HIBERNATION SETUP LOGIC
# ===========================================================================================

if is_btrfs && is_laptop && confirm "Set up hibernation?"; then
  print_box "smslant" "Hibernation"
  print_step "Setting up hibernation"

  create_backup "$MKINIT_CONF"
  create_backup "/etc/fstab"

  if [[ $(detect_bootloader) == "grub" ]]; then
    create_backup "/etc/default/grub"
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

  # nvidia services
  if [[ $gpu_info == *"NVIDIA Corporation"* ]]; then
    enable_service "nvidia-suspend-then-hibernate.service" "system"
    enable_service "nvidia-hibernate.service" "system"
    enable_service "nvidia-suspend.service" "system"
    enable_service "nvidia-resume.service" "system"

    write_system_config "/etc/tmpfiles.d/nvidia_pm.conf" "nvidia power management config" <<'EOF'
# /etc/tmpfiles.d/nvidia_pm.conf# /etc/tmpfiles.d/nvidia_pm.conf
w /sys/bus/pci/devices/0000:01:00.0/power/control - - - - auto
EOF
  fi
fi
