#!/bin/bash

# Constants
readonly SWAP_SIZE="38G"
readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
readonly WAKE_DEVICES_RULE_FILE="/etc/udev/rules.d/90-wake-devices.rules"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

get_btrfs_root_device() {
  local device
  device=$(findmnt -n -o SOURCE --target /mnt 2>/dev/null || findmnt -n -o SOURCE --target / 2>/dev/null)
  if [[ -z "$device" ]]; then
    return 1
  fi
  # Strip subvolume suffix if present (format: /dev/device[subvol])
  device="${device%%\[*}"
  echo "$device"
}

btrfs_subvolume_exists() {
  local subvol_name="$1"
  local mount_point="$2"
  sudo btrfs subvolume list "$mount_point" | grep -q "path ${subvol_name}$"
}

is_swapfile_active() {
  sudo swapon --show | grep -q "$SWAP_FILE_PATH"
}

is_btrfs() {
  findmnt -n -o FSTYPE / | grep -q btrfs
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
# AUTO-CPUFREQ INSTALLATION AND CONFIGURATION
# =============================================================================

download_and_install_auto_cpufreq() {
  printc cyan "Installing auto-cpufreq... "
  local tmp_dir
  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory"

  if git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$tmp_dir" 2>/dev/null &&
    cd "$tmp_dir" && sudo ./auto-cpufreq-installer; then
    rm -rf "$tmp_dir"

  else
    rm -rf "$tmp_dir"
    fail "FAILED"
  fi
}

finalize_auto_cpufreq_installation() {
  printc -n cyan "Finalizing auto-cpufreq... "
  if sudo auto-cpufreq --install >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

install_auto_cpufreq() {
  if has_cmd auto-cpufreq; then
    printc green "auto-cpufreq already installed"
    return 0
  fi

  download_and_install_auto_cpufreq
  finalize_auto_cpufreq_installation
}

enable_auto_cpufreq_service() {
  printc cyan "Enabling auto-cpufreq service..."
  enable_service "auto-cpufreq.service" "system"
}

# =============================================================================
# BTRFS SWAP CONFIGURATION
# =============================================================================

mount_swap_subvolume() {
  printc -n cyan "Mounting swap subvolume... "
  sudo mkdir -p "$SWAP_MOUNT_POINT"
  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    local btrfs_device
    btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
    if sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_device" "$SWAP_MOUNT_POINT"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already mounted"
  fi
}

create_btrfs_swap_subvolume() {
  printc -n cyan "Creating swap subvolume... "
  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"

  local temp_mount="/tmp/btrfs-root"
  sudo mkdir -p "$temp_mount"
  sudo mount "$btrfs_device" "$temp_mount" || fail "Failed to mount Btrfs root"

  if ! btrfs_subvolume_exists "$SWAP_SUBVOL" "$temp_mount"; then
    if sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      printc green "OK"
    else
      sudo umount "$temp_mount"
      fail "FAILED"
    fi
  else
    printc yellow "already exists"
  fi

  sudo umount "$temp_mount"
  mount_swap_subvolume
}

create_swapfile() {
  printc -n cyan "Creating swapfile... "
  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    mount_swap_subvolume
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    if sudo btrfs filesystem mkswapfile --size "$SWAP_SIZE" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already exists"
  fi
}

activate_swapfile() {
  printc -n cyan "Activating swapfile... "
  if ! is_swapfile_active; then
    if sudo swapon "$SWAP_FILE_PATH"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already active"
  fi
}

add_swap_subvolume_to_fstab() {
  printc -n cyan "Adding swap mount to fstab... "
  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs device"
  UUID=$(sudo blkid -s UUID -o value "$btrfs_device") || fail "Failed to get UUID"

  local fstab_entry="UUID=$UUID $SWAP_MOUNT_POINT btrfs defaults,nodatacow,noatime,subvol=$SWAP_SUBVOL 0 0"

  if ! grep -q "$fstab_entry" /etc/fstab; then
    if echo -e "\n$fstab_entry\n" | sudo tee -a /etc/fstab >/dev/null; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already exists"
  fi
}

add_swapfile_to_fstab() {
  printc -n cyan "Adding swapfile to fstab... "
  if ! grep -q "$SWAP_FILE_PATH" /etc/fstab; then
    if echo -e "\n$SWAP_FILE_PATH none swap defaults 0 0\n" | sudo tee -a /etc/fstab >/dev/null; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already exists"
  fi
}

create_and_activate_swapfile() {
  create_swapfile
  activate_swapfile
}

setup_btrfs_swap() {
  printc cyan "Setting up Btrfs swap configuration..."
  create_btrfs_swap_subvolume
  add_swap_subvolume_to_fstab
  create_and_activate_swapfile
  add_swapfile_to_fstab
}

# =============================================================================
# HIBERNATION CONFIGURATION
# =============================================================================

set_resume_offset() {
  printc -n cyan "Setting resume offset... "
  local resume_offset
  if resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") &&
    echo "$resume_offset" | sudo tee /sys/power/resume_offset >/dev/null &&
    echo lz4 | sudo tee /sys/module/hibernate/parameters/compressor >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_initramfs_resume_hook() {
  printc -n cyan "Configuring initramfs... "
  if ! grep -q 'HOOKS=.*resume' "$MKINIT_CONF"; then
    if sudo sed -i -E 's/^(HOOKS=.* )(udev|base)(.*)$/\1\2 resume\3/' "$MKINIT_CONF"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already configured"
  fi
}

wake_devices() {
  printc -n cyan "Configuring wake devices... "
  if sudo tee "$WAKE_DEVICES_RULE_FILE" >/dev/null <<'EOF' && reload_udev_rules >/dev/null 2>&1; then
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/local/bin/toggle_wake_devices.sh disable"
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/local/bin/toggle_wake_devices.sh enable"
EOF
    printc green "OK"
  else
    fail "FAILED"
  fi
}

edit_hibernation_conf() {
  printc -n cyan "Writing hibernation config... "
  if sudo mkdir -p /etc/systemd/sleep.conf.d && sudo tee /etc/systemd/sleep.conf.d/hibernation.conf >/dev/null <<'EOF'; then
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateMode=shutdown
EOF
    printc green "OK"
  else
    fail "FAILED"
  fi
}

configure_hibernation_support() {
  set_resume_offset
  configure_initramfs_resume_hook
  wake_devices
  edit_hibernation_conf
}

# =============================================================================
# TOUCHPAD AND INPUT CONFIGURATION
# =============================================================================

write_touchpad_udev_rule() {
  printc -n cyan "Writing touchpad udev rule... "
  if sudo tee "$TOUCHPAD_RULE_FILE" >/dev/null <<'EOF'; then
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF
    printc green "OK"
  else
    fail "FAILED"
  fi
}

setup_touchpad_udev_rule() {
  write_touchpad_udev_rule
  reload_udev_rules
}

enable_libinput_gestures() {
  if ! has_cmd "libinput-gestures"; then
    install_package "libinput-gestures"
  fi
  enable_service "libinput-gestures.service" "user"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  install_auto_cpufreq
  enable_auto_cpufreq_service

  if is_btrfs; then
    if confirm "Setup hibernation ?"; then
      setup_btrfs_swap
      configure_hibernation_support
    else
      printc yellow "Skipping hibernation setup."
    fi
  else
    printc yellow "Btrfs is not detected. Skipping Btrfs-specific setup."
  fi

  setup_touchpad_udev_rule
  enable_libinput_gestures
}

main
