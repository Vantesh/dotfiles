#!/bin/bash

# Constants
readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
readonly WAKE_DEVICES_RULE_FILE="/etc/udev/rules.d/90-wake-devices.rules"
readonly MKINIT_HOOKS="HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems)"

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
  awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo
}

calculate_swap_size() {
  local ram_gb
  ram_gb=$(get_ram_size_gb)
  local swap_gb=$((ram_gb + 8))
  echo "${swap_gb:-4}G"
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

detect_limine_bootloader() {
  has_cmd limine-update || [[ -x /usr/bin/limine-update ]]
}

btrfs_subvolume_exists() {
  sudo btrfs subvolume list "$2" | grep -q "path $1$"
}

is_swapfile_active() {
  sudo swapon --show | grep -q "$SWAP_FILE_PATH"
}

reload_udev_rules() {
  printc -n cyan "Reloading udev rules... "
  if sudo udevadm control --reload-rules && sudo udevadm trigger; then
    printc green "OK"
  else
    fail "FAILED"
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
    printc yellow "already exists"
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
    printc yellow "already exists"
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
    printc yellow "already exists"
    return 0
  fi

  if echo -e "\n$entry\n" | sudo tee -a /etc/fstab >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

setup_btrfs_swap() {
  printc cyan "Setting up Btrfs swap configuration..."

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
  local uuid
  uuid=$(sudo blkid -s UUID -o value "$btrfs_device") || fail "Failed to get UUID"

  create_btrfs_swap_subvolume
  add_to_fstab "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,nodatacow,noatime,subvol=$SWAP_SUBVOL 0 0" "swap mount"
  create_swapfile
  activate_swapfile
  add_to_fstab "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"
}

# =============================================================================
# HIBERNATION CONFIGURATION
# =============================================================================

configure_limine_hibernation() {
  printc -n cyan "Configuring Limine for hibernation... "

  local btrfs_device resume_offset root_partuuid
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
  resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") || fail "Failed to get resume offset"
  root_partuuid=$(sudo blkid -s PARTUUID -o value "$btrfs_device") || fail "Failed to get root PARTUUID"

  local limine_conf="/etc/default/limine"
  local kernel_params="root=PARTUUID=$root_partuuid rootfstype=btrfs rootflags=subvol=@ rw resume=$btrfs_device resume_offset=$resume_offset hibernate=lz4"

  if [[ ! -f "$limine_conf" ]]; then
    install_package "limine-mkinitcpio-hook"
    sudo cp /etc/limine-entry-tool.conf "$limine_conf"
  fi

  if grep -q "resume=" "$limine_conf"; then
    printc yellow "Exists"
    return 0
  fi

  update_config "$limine_conf" "KERNEL_CMDLINE[default]" "\"$kernel_params\""
  printc green "OK"
}

configure_initramfs() {
  printc -n cyan "Configuring initramfs... "

  if grep -q '^[[:space:]]*HOOKS=.*systemd' "$MKINIT_CONF"; then
    printc yellow "Exists"
    return 0
  fi

  if sudo sed -i -E "s/^HOOKS=\(.*\)$/$MKINIT_HOOKS/" "$MKINIT_CONF"; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

write_system_config() {
  local config_file="$1"
  local description="$2"
  shift 2

  printc -n cyan "Writing $description... "

  if sudo mkdir -p "$(dirname "$config_file")" && sudo tee "$config_file" >/dev/null; then
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
HibernateMode=shutdown
EOF

  # Wake devices rule
  write_system_config "$WAKE_DEVICES_RULE_FILE" "wake devices rule" <<'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/local/bin/toggle_wake_devices.sh disable"
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/local/bin/toggle_wake_devices.sh enable"
EOF
  reload_udev_rules >/dev/null 2>&1

  # Set resume offset
  printc -n cyan "Setting resume offset... "
  local resume_offset
  if resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") &&
    echo "$resume_offset" | sudo tee /sys/power/resume_offset >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

enable_nvidia_hibernation_services() {
  printc -n cyan "Enabling NVIDIA hibernation services... "

  local nvidia_services=(
    "nvidia-suspend.service"
    "nvidia-hibernate.service"
    "nvidia-resume.service"
    "nvidia-suspend-then-hibernate.service"
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
  configure_limine_hibernation
  configure_initramfs

  detect_nvidia_gpu && enable_nvidia_hibernation_services
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
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  install_dependencies
  enable_service "upower.service" "system"

  if is_btrfs && detect_limine_bootloader && confirm "Setup hibernation?"; then
    setup_btrfs_swap
    configure_hibernation_support
  else
    if ! is_btrfs; then
      printc yellow "No Btrfs filesystem detected. Skipping Btrfs setup"
    elif ! detect_limine_bootloader; then
      printc yellow "Limine bootloader not detected. Skipping hibernation setup"
    else
      printc yellow "Skipping Btrfs swap and hibernation setup."
    fi
  fi

  setup_touchpad
  enable_service "libinput-gestures.service" "user"
}

main
