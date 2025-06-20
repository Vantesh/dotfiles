#!/bin/bash

# ========================
# Constants
# ========================
readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"

# ========================
# Dependencies
# ========================
deps=(
  upower
  auto-cpufreq
)

install_all_dependencies() {
  for dep in "${deps[@]}"; do
    install_package "$dep"
  done
}

# ========================
# Utility Functions
# ========================

get_ram_size_gb() {
  awk '/MemTotal/ {printf "%d\n", int(($2 + 1024 * 1024 - 1) / (1024 * 1024)) + ((($2 + 1024 * 1024 - 1) % (1024 * 1024)) > 0 ? 1 : 0)}' /proc/meminfo
}

calculate_swap_size() {
  local ram_gb
  ram_gb=$(get_ram_size_gb)

  local sqrt_ram
  sqrt_ram=$(awk "BEGIN {printf \"%.0f\", sqrt($ram_gb)}")

  local swap_gb=$((ram_gb + sqrt_ram))
  [[ $swap_gb -lt 1 ]] && swap_gb=1

  echo "${swap_gb}G"
}

get_btrfs_root_device() {
  local device
  device=$(findmnt -n -o SOURCE --target / 2>/dev/null)
  [[ -n "$device" ]] && echo "${device%%\[*}"
}

is_btrfs() {
  findmnt -n -o FSTYPE / | grep -q btrfs
}

detect_nvidia_gpu() {
  lspci -nn | grep -Eiq "NVIDIA Corporation.*(GeForce|RTX|GTX|Quadro)"
}

btrfs_subvolume_exists() {
  sudo btrfs subvolume list "$2" | grep -q "path $1$"
}

is_swapfile_active() {
  sudo swapon --show | grep -q "$SWAP_FILE_PATH"
}

is_any_non_zram_swap_active() {
  sudo swapon --show --noheadings | awk '{print $1}' | grep -v '^/dev/zram' | grep -qE '^/dev/|^/'
}

get_active_non_zram_swap_path() {
  sudo swapon --show --noheadings | awk '{print $1}' | grep -v '^/dev/zram' | head -n1
}

is_swap_path_partition() {
  [[ -b "$1" ]]
}

reload_udev_rules() {
  printc -n cyan "Reloading udev rules... "
  if sudo udevadm control --reload-rules && sudo udevadm trigger; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

reload_systemd_daemon() {
  printc -n cyan "Reloading systemd daemon... "
  if sudo systemctl daemon-reload; then
    printc green "OK"
  else
    printc yellow "FAILED"
  fi
}

# ========================
# auto-cpufreq Installation
# ========================

install_auto_cpufreq() {
  printc -n cyan "Installing auto-cpufreq... "
  if sudo auto-cpufreq --install >/dev/null 2>&1; then
    printc green "OK"
  else
    printc yellow "Failed, Manually setup auto-cpufreq"
  fi

}
# ========================
# Btrfs Swap Configuration
# ========================

mount_btrfs_swap_subvolume() {
  printc -n cyan "Mounting swap subvolume ($SWAP_MOUNT_POINT)... "
  sudo mkdir -p "$SWAP_MOUNT_POINT"

  if mountpoint -q "$SWAP_MOUNT_POINT"; then
    printc yellow "already mounted"
    return 0
  fi

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device for swap mount"

  if sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_device" "$SWAP_MOUNT_POINT"; then
    printc green "OK"
  else
    fail "FAILED to mount swap subvolume"
  fi
}

create_btrfs_swap_subvolume() {
  printc -n cyan "Creating swap subvolume ($SWAP_SUBVOL)... "
  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device for subvolume creation"

  local temp_mount="/tmp/btrfs-root"
  sudo mkdir -p "$temp_mount"
  sudo mount "$btrfs_device" "$temp_mount" || fail "Failed to mount Btrfs root to $temp_mount"

  if btrfs_subvolume_exists "$SWAP_SUBVOL" "$temp_mount"; then
    printc yellow "exists"
  else
    if sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      printc green "OK"
    else
      sudo umount "$temp_mount"
      fail "FAILED to create subvolume"
    fi
  fi
  sudo umount "$temp_mount"

}

create_btrfs_swapfile() {
  local swap_size
  swap_size=$(calculate_swap_size)
  printc -n cyan "Creating ${swap_size} Btrfs swapfile... "

  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    mount_btrfs_swap_subvolume
  fi
  if [[ -f "$SWAP_FILE_PATH" ]]; then
    printc yellow "exists"
    return 0
  fi

  if sudo btrfs filesystem mkswapfile --size "$swap_size" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED to create swapfile"
  fi
}

activate_swapfile() {
  printc -n cyan "Activating swapfile... "

  if is_swapfile_active; then
    printc yellow "already active"
    return 0
  fi

  if sudo swapon "$SWAP_FILE_PATH"; then
    printc green "OK"
  else
    fail "FAILED to activate swapfile"
  fi
}

add_entry_to_fstab() {
  local entry="$1"
  local description="$2"

  printc -n cyan "Adding $description to fstab... "

  if grep -qF "$entry" /etc/fstab; then
    printc yellow "exists"
    return 0
  fi

  if echo -e "\n$entry\n" | sudo tee -a /etc/fstab >/dev/null; then
    printc green "OK"
    reload_systemd_daemon
  else
    fail "FAILED to add $description to fstab"
  fi
}

setup_btrfs_swap() {
  printc cyan "Setting up Btrfs swap configuration..."

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device for swap setup"
  local uuid
  uuid=$(sudo blkid -s UUID -o value "$btrfs_device") || fail "Failed to get UUID for Btrfs device"

  create_btrfs_swap_subvolume && mount_btrfs_swap_subvolume
  add_entry_to_fstab "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0" "swap subvolume mount"
  create_btrfs_swapfile
  activate_swapfile
  add_entry_to_fstab "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    fail "Swapfile creation failed, cannot proceed with Btrfs hibernation setup"
  fi
}

# ========================
# Hibernation Configuration
# ========================
get_hibernation_kernel_params() {
  local swap_path resume_uuid resume_offset hibernation_params

  swap_path=$(get_active_non_zram_swap_path) || return 1
  [[ -z "$swap_path" ]] && return 1

  if is_swap_path_partition "$swap_path"; then
    resume_uuid=$(sudo blkid -s UUID -o value "$swap_path" 2>/dev/null) || return 1
    [[ -z "$resume_uuid" ]] && return 1
    hibernation_params="resume=UUID=$resume_uuid"

  elif [[ -f "$swap_path" ]]; then
    local btrfs_root_device
    btrfs_root_device=$(get_btrfs_root_device) || return 1
    [[ -z "$btrfs_root_device" ]] && return 1

    resume_uuid=$(sudo blkid -s UUID -o value "$btrfs_root_device" 2>/dev/null) || return 1
    resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$swap_path" 2>/dev/null | awk '{print $1}') || return 1

    [[ -z "$resume_uuid" || -z "$resume_offset" ]] && return 1
    hibernation_params="resume=UUID=$resume_uuid resume_offset=$resume_offset"

  else
    return 1
  fi

  echo "$hibernation_params hibernate.compressor=lz4"
  return 0
}

configure_hibernation_cmdline() {
  local swap_path
  swap_path=$(get_active_non_zram_swap_path)

  if [[ -z "$swap_path" ]]; then
    fail "No active non-zram swap found to configure hibernation parameters"
  fi

  local hibernation_params
  if is_swap_path_partition "$swap_path"; then
    printc -n cyan "Detected swap partition '$swap_path'. Getting hibernation parameters... "
  elif [[ -f "$swap_path" ]]; then
    printc -n cyan "Detected swapfile '$swap_path'. Getting hibernation parameters... "
  fi

  if ! hibernation_params=$(get_hibernation_kernel_params); then
    fail "FAILED to get hibernation parameters"
  fi

  printc green "OK"
  update_kernel_cmdline "$hibernation_params"
}

configure_initramfs() {
  printc -n cyan "Configuring initramfs hooks... "

  local hooks="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems"

  if sudo sed -i -E "s/^HOOKS=\([^)]*\)/HOOKS=($hooks)/" "$MKINIT_CONF"; then
    printc green "OK"
  else
    fail "FAILED to configure initramfs"
  fi
}

write_hibernation_configs() {
  write_system_config "/etc/systemd/sleep.conf.d/hibernation.conf" "systemd sleep config" <<'EOF'
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateMode=shutdown
MemorySleepMode=deep
HibernateDelaySec=30min
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

  write_system_config "/etc/systemd/system/user-suspend@.service" "user suspend service" <<'EOF'
[Unit]
Description=User Suspend Actions
Before=sleep.target

[Service]
User=%i
Type=simple
Environment=XDG_RUNTIME_DIR="/run/user/$(id -u %i)"
ExecStart=/usr/bin/hyprlock
ExecStartPost=/usr/bin/sleep 1

[Install]
WantedBy=sleep.target
EOF

  local current_user
  current_user=$(logname 2>/dev/null || whoami)
  enable_service "user-suspend@${current_user}.service" "system"

  # Configure hibernation image size for systems with more than 16GB RAM
  local ram_gb
  ram_gb=$(get_ram_size_gb)
  if [[ $ram_gb -gt 16 ]]; then
    write_system_config "/etc/tmpfiles.d/hibernation_image_size.conf" "hibernation image size config" <<'EOF'
#    Path                   Mode UID  GID  Age Argument
w    /sys/power/image_size  -    -    -    -   0
EOF
  fi

}

enable_nvidia_hibernation_services() {
  printc -n cyan "Enabling NVIDIA hibernation services... "

  local nvidia_services=(
    "nvidia-suspend-then-hibernate.service"
    "nvidia-suspend.service"
    "nvidia-hibernate.service"
    "nvidia-resume.service"
  )

  local enabled_count=0
  for service in "${nvidia_services[@]}"; do
    if enable_service "$service" "system" >/dev/null 2>&1; then
      ((enabled_count++))
    fi
  done

  if [[ $enabled_count -eq ${#nvidia_services[@]} ]]; then
    printc green "OK"
  else
    printc yellow "partial ($enabled_count/${#nvidia_services[@]})"
  fi
}

setup_system_hibernation() {
  if ! is_any_non_zram_swap_active; then
    fail "No active non-zram swap found. Hibernation cannot be configured."
  fi
  configure_hibernation_cmdline
  configure_initramfs && sleep 2 && regenerate_initramfs
  detect_nvidia_gpu && enable_nvidia_hibernation_services
  write_hibernation_configs
}

# ========================
# Input Configuration
# ========================

setup_touchpad() {
  printc_box "Touchpad Configuration" "Configuring touchpad access for user..."
  install_package "libinput-gestures"
  write_system_config "$TOUCHPAD_RULE_FILE" "touchpad udev rule" <<'EOF'
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF
  reload_udev_rules
  enable_service "libinput-gestures.service" "user"
}

# ========================
# Btrfs Configuration
# ========================

update_btrfs_fstab_options() {
  printc -n cyan "Updating Btrfs fstab options to use noatime... "

  local fstab_backup
  fstab_backup="/etc/fstab.bak.$(date +%s)"

  sudo cp /etc/fstab "$fstab_backup" || {
    fail "Failed to backup fstab"
    return 1
  }

  if sudo sed -i -E '/btrfs/ { s/\brelatime\b/noatime/g; s/\bdefaults\b/defaults,noatime/g; s/(,noatime){2,}/,noatime/g; s/,+/,/g; }' /etc/fstab; then
    printc green "OK"
    reload_systemd_daemon
  else
    printc yellow "FAILED"
    sudo cp "$fstab_backup" /etc/fstab || fail "Failed to restore fstab from backup"
  fi
}

# ========================
# Main Execution
# ========================

main() {
  ensure_sudo
  install_all_dependencies
  install_auto_cpufreq
  enable_service "upower.service" "system"

  if echo && confirm "Would you like to set up hibernation support?"; then
    printc_box "Hibernation Setup" "Configuring system hibernation"
    if is_any_non_zram_swap_active; then
      setup_system_hibernation
    elif is_btrfs; then
      if setup_btrfs_swap; then
        setup_system_hibernation
      fi
    else
      printc yellow "No active non-zram swap found and not using Btrfs. Skipping hibernation setup."
    fi
  else
    printc yellow "Skipping hibernation setup"
  fi

  if is_btrfs; then
    update_btrfs_fstab_options
  fi

  setup_touchpad

}

main
