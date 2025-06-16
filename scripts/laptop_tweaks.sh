#!/bin/bash

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/bootloader.sh"

# Constants
readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
readonly WAKE_DEVICES_RULE_FILE="/etc/udev/rules.d/90-wake-devices.rules"

# =============================================================================
# DEPENDENCIES
# =============================================================================
deps=(
  upower
  auto-cpufreq
  libinput-gestures
)

install_dependencies() {
  for dep in "${deps[@]}"; do
    if [[ "$dep" == "auto-cpufreq" ]]; then
      install_auto_cpufreq
    else
      install_package "$dep"
    fi
  done
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
get_ram_size_gb() {
  # Use awk to round up to the nearest whole GB
  awk '/MemTotal/ {printf "%d\n", int(($2 + 1024 * 1024 - 1) / (1024 * 1024)) + ((($2 + 1024 * 1024 - 1) % (1024 * 1024)) > 0 ? 1 : 0)}' /proc/meminfo
}

calculate_swap_size() {
  local ram_gb
  ram_gb=$(get_ram_size_gb)

  # Calculate square root of RAM size using awk for floating point math
  local sqrt_ram
  sqrt_ram=$(awk "BEGIN {printf \"%.0f\", sqrt($ram_gb)}")

  # Swap = RAM + √RAM
  local swap_gb=$((ram_gb + sqrt_ram))

  # Ensure minimum of 1GB
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

has_existing_swap_partition() {
  local swap_devices
  swap_devices=$(sudo swapon --show --noheadings | awk '{print $1}' | grep -v '^/dev/zram')
  [[ -n "$swap_devices" ]]
}

get_swap_device_uuid() {
  local swap_device
  swap_device=$(sudo swapon --show --noheadings | awk '{print $1}' | grep -v '^/dev/zram' | head -n1)
  [[ -n "$swap_device" ]] && sudo blkid -s UUID -o value "$swap_device"
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

# =============================================================================
# AUTO-CPUFREQ INSTALLATION
# =============================================================================

install_auto_cpufreq() {
  printc -n cyan "Installing auto-cpufreq..."
  if has_cmd auto-cpufreq; then
    printc green "Exists"
    return 0
  fi
  local tmp_dir
  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory"
  if git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$tmp_dir" 2>/dev/null &&
    cd "$tmp_dir" && echo "I" | sudo ./auto-cpufreq-installer >/dev/null 2>&1; then
    sleep 2
    if sudo auto-cpufreq --install >/dev/null 2>&1; then
      printc green "OK"
    else
      printc yellow "Failed, trying to set up manually"
    fi
    rm -rf "$tmp_dir"
  else
    rm -rf "$tmp_dir"
    fail "Failed"
  fi
}

# =============================================================================
# BTRFS SWAP CONFIGURATION
# =============================================================================

mount_swap_subvolume() {
  printc -n cyan "Mounting swap subvolume... "
  sudo mkdir -p "$SWAP_MOUNT_POINT"

  if mountpoint -q "$SWAP_MOUNT_POINT"; then
    printc yellow "already mounted"
    return 0
  fi

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"

  if sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_device" "$SWAP_MOUNT_POINT"; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

create_btrfs_swap_subvolume() {
  printc -n cyan "Creating swap subvolume... "
  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"

  local temp_mount="/tmp/btrfs-root"
  sudo mkdir -p "$temp_mount"
  sudo mount "$btrfs_device" "$temp_mount" || fail "Failed to mount Btrfs root"

  if btrfs_subvolume_exists "$SWAP_SUBVOL" "$temp_mount"; then
    printc yellow "exists"
  else
    if sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      printc green "OK"
    else
      sudo umount "$temp_mount"
      fail "FAILED"
    fi
  fi

  sudo umount "$temp_mount"
  mount_swap_subvolume
}

create_swapfile() {
  local swap_size
  swap_size=$(calculate_swap_size)
  printc -n cyan "Creating ${swap_size} swapfile... "

  mountpoint -q "$SWAP_MOUNT_POINT" || mount_swap_subvolume

  if [[ -f "$SWAP_FILE_PATH" ]]; then
    printc yellow "exists"
    return 0
  fi

  if sudo btrfs filesystem mkswapfile --size "$swap_size" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
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
    fail "FAILED"
  fi
}

add_to_fstab() {
  local entry="$1"
  local description="$2"

  printc -n cyan "Adding $description to fstab... "

  if grep -q "$entry" /etc/fstab; then
    printc yellow "exists"
    return 0
  fi

  if echo -e "\n$entry\n" | sudo tee -a /etc/fstab >/dev/null; then
    printc green "OK"
    reload_systemd_daemon
  else
    fail "FAILED"
  fi
}

setup_btrfs_swap() {
  printc cyan "Setting up Btrfs swap configuration..."

  # Check for existing swap partitions (excluding zram)
  if has_existing_swap_partition; then
    printc yellow "Existing swap partition detected. Skipping swap file creation."
    return 0
  fi

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
  local uuid
  uuid=$(sudo blkid -s UUID -o value "$btrfs_device") || fail "Failed to get UUID"

  create_btrfs_swap_subvolume
  add_to_fstab "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0" "swap mount"
  create_swapfile
  activate_swapfile
  add_to_fstab "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"
}

# =============================================================================
# HIBERNATION CONFIGURATION
# =============================================================================

configure_hibernation_cmdline() {
  local resume_uuid hibernation_params

  if has_existing_swap_partition; then
    # Use swap partition UUID
    resume_uuid=$(get_swap_device_uuid) || fail "Failed to get swap partition UUID"
    hibernation_params="resume=UUID=$resume_uuid hibernate.compressor=lz4"
  else
    # Use Btrfs device UUID and add resume_offset for swap file
    local btrfs_device resume_offset
    btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
    resume_uuid=$(sudo blkid -s UUID -o value "$btrfs_device") || fail "Failed to get Btrfs UUID"
    resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") || fail "Failed to get resume offset"
    hibernation_params="resume=UUID=$resume_uuid resume_offset=$resume_offset hibernate.compressor=lz4"
  fi

  # Use the function from bootloader.sh
  update_kernel_cmdline "$hibernation_params"
}

configure_initramfs() {
  printc -n cyan "Configuring initramfs... "

  local hooks="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems"

  if sudo sed -i -E "s/^HOOKS=\([^)]*\)/HOOKS=($hooks)/" "$MKINIT_CONF"; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_hibernation_services() {
  write_system_config "/etc/systemd/sleep.conf.d/hibernation.conf" "hibernation config" <<'EOF'
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
#SuspendState=mem disk
HibernateMode=shutdown
#MemorySleepMode=deep
HibernateDelaySec=30min
#HibernateOnACPower=no
#SuspendEstimationSec=60min
EOF

  write_system_config "/etc/systemd/logind.conf.d/hibernation.conf" "logind hibernation config" <<'EOF'
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=suspend-then-hibernate
EOF

  # User suspend service for hyprlock
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

  write_system_config "$WAKE_DEVICES_RULE_FILE" "wake devices rule" <<'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/local/bin/toggle_wake_devices.sh disable"
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/local/bin/toggle_wake_devices.sh enable"
EOF
  reload_udev_rules >/dev/null 2>&1

  if ! has_existing_swap_partition; then
    printc -n cyan "Setting resume offset... "
    local resume_offset
    if resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") &&
      echo "$resume_offset" | sudo tee /sys/power/resume_offset >/dev/null; then
      printc green "OK"
    else
      fail "FAILED"
    fi
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

configure_hibernation_support() {
  configure_hibernation_services
  configure_hibernation_cmdline
  configure_initramfs
  detect_nvidia_gpu && enable_nvidia_hibernation_services
  regenerate_initramfs

}

# =============================================================================
# INPUT CONFIGURATION
# =============================================================================

setup_touchpad() {
  write_system_config "$TOUCHPAD_RULE_FILE" "touchpad udev rule" <<'EOF'
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF
  reload_udev_rules
}

# =============================================================================
# BTRFS CONFIGURATION
# =============================================================================

update_btrfs_fstab_options() {
  printc -n cyan "Updating Btrfs fstab options to use noatime... "

  local fstab_backup
  fstab_backup="/etc/fstab.bak.$(date +%s)"
  sudo cp /etc/fstab "$fstab_backup"

  # Update relatime to noatime for btrfs filesystems
  if sudo sed -i 's/\(.*btrfs.*\)relatime\(.*\)/\1noatime\2/g' /etc/fstab; then
    # Also ensure defaults includes noatime for btrfs entries that don't have explicit relatime
    sudo sed -i '/btrfs.*defaults[^,]*$/s/defaults/defaults,noatime/' /etc/fstab
    sudo sed -i '/btrfs.*defaults,/s/defaults,/defaults,noatime,/' /etc/fstab
    # Remove duplicate noatime entries
    sudo sed -i 's/noatime,noatime/noatime/g' /etc/fstab
    printc green "OK"
    reload_systemd_daemon
  else
    printc yellow "FAILED"
    sudo cp "$fstab_backup" /etc/fstab
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  install_dependencies
  enable_service "upower.service" "system"

  if is_btrfs; then
    update_btrfs_fstab_options
  fi

  if is_btrfs && confirm "Setup hibernation?"; then
    setup_btrfs_swap
    configure_hibernation_support
  else
    if ! is_btrfs; then
      printc yellow "No Btrfs filesystem detected. Skipping Btrfs setup"
    fi
  fi

  setup_touchpad
  enable_service "libinput-gestures.service" "user"
}

main
