#!/bin/bash

# Constants
readonly SWAP_SIZE="38G"
readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"
readonly MKINIT_CONF="/etc/mkinitcpio.conf"
readonly TOUCHPAD_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
readonly WAKE_DEVICES_RULE_FILE="/etc/udev/rules.d/90-wake-devices.rules"

install_auto_cpufreq() {
  printc cyan "Checking auto-cpufreq installation..."

  if has_cmd auto-cpufreq; then
    printc green "auto-cpufreq is already installed."
    return 0
  fi

  download_and_install_auto_cpufreq
  finalize_auto_cpufreq_installation
}

download_and_install_auto_cpufreq() {
  printc yellow "Installing auto-cpufreq..."
  local tmp_dir
  tmp_dir=$(mktemp -d) || fail "Failed to create temp directory for auto-cpufreq."

  git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$tmp_dir" || {
    rm -rf "$tmp_dir"
    fail "Failed to clone auto-cpufreq repo."
  }

  pushd "$tmp_dir" >/dev/null || {
    rm -rf "$tmp_dir"
    fail "Failed to enter auto-cpufreq directory."
  }

  sudo ./auto-cpufreq-installer || {
    popd >/dev/null || exit 1
    rm -rf "$tmp_dir"
    fail "auto-cpufreq installation failed."
  }

  popd >/dev/null || exit 1
  rm -rf "$tmp_dir"
}

finalize_auto_cpufreq_installation() {
  sudo auto-cpufreq --install || fail "Failed to finalize auto-cpufreq installation."
  printc green "auto-cpufreq installed successfully."
}

enable_auto_cpufreq_service() {
  printc cyan "Enabling auto-cpufreq service..."
  enable_service "auto-cpufreq.service" "system"
}

create_btrfs_swap_subvolume() {
  printc cyan "Ensuring Btrfs subvolume for swap exists and is properly mounted..."

  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs root device."

  # Temporarily mount root of Btrfs to access top-level subvolumes
  local temp_mount="/tmp/btrfs-root"
  sudo mkdir -p "$temp_mount"
  sudo mount "$btrfs_device" "$temp_mount" || fail "Failed to mount Btrfs root at $temp_mount."

  if ! btrfs_subvolume_exists "$SWAP_SUBVOL" "$temp_mount"; then
    sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" || fail "Failed to create Btrfs subvolume for swap."
    printc green "Created Btrfs subvolume ${SWAP_SUBVOL}."
  else
    printc yellow "Btrfs subvolume ${SWAP_SUBVOL} already exists."
  fi

  sudo umount "$temp_mount"

  mount_swap_subvolume
}

btrfs_subvolume_exists() {
  local subvol_name="$1"
  local mount_point="$2"
  sudo btrfs subvolume list "$mount_point" | grep -q "path ${subvol_name}$"
}

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

mount_swap_subvolume() {
  sudo mkdir -p "$SWAP_MOUNT_POINT"
  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    local btrfs_device
    btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs root device."
    sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_device" "$SWAP_MOUNT_POINT" || fail "Failed to mount $SWAP_SUBVOL at $SWAP_MOUNT_POINT."
    printc green "Mounted ${SWAP_SUBVOL} at ${SWAP_MOUNT_POINT}."
  else
    printc yellow "${SWAP_MOUNT_POINT} is already mounted."
  fi

  # Verify the mount is working and directory is accessible
  if [[ ! -d "$SWAP_MOUNT_POINT" ]] || ! sudo test -w "$SWAP_MOUNT_POINT"; then
    fail "Swap mount point $SWAP_MOUNT_POINT is not accessible or writable."
  fi
}

create_and_activate_swapfile() {
  create_swapfile
  activate_swapfile
}

create_swapfile() {
  printc cyan "Creating swap file..."

  # Ensure swap mount point is properly mounted first
  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    printc yellow "Swap mount point not mounted, attempting to mount..."
    mount_swap_subvolume
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    sudo btrfs filesystem mkswapfile --size "$SWAP_SIZE" --uuid clear "$SWAP_FILE_PATH" ||
      fail "Failed to create swap file."
    printc green "Swap file created successfully at $SWAP_FILE_PATH."
  else
    printc yellow "Swap file already exists at $SWAP_FILE_PATH."
  fi

  # Verify the swapfile is accessible
  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    fail "Swapfile was not created successfully at $SWAP_FILE_PATH."
  fi
}

activate_swapfile() {
  printc cyan "Activating swap file..."
  if ! is_swapfile_active; then
    sudo swapon "$SWAP_FILE_PATH" || fail "Failed to activate swap file."
    printc green "Swap file activated successfully."
  else
    printc yellow "Swap file is already active."
  fi
}

is_swapfile_active() {
  sudo swapon --show | grep -q "$SWAP_FILE_PATH"
}

add_swapfile_to_fstab() {
  printc cyan "Adding swap file to fstab..."
  if ! grep -q "$SWAP_FILE_PATH" /etc/fstab; then
    echo -e "\n$SWAP_FILE_PATH none swap defaults 0 0\n" | sudo tee -a /etc/fstab ||
      fail "Failed to add swap file to fstab."
    printc green "Swap file added to fstab successfully."
  else
    printc yellow "Swap file already exists in fstab."
  fi
}

add_swap_subvolume_to_fstab() {
  printc cyan "Adding swap subvolume mount to fstab..."
  local btrfs_device
  btrfs_device=$(get_btrfs_root_device) || fail "Failed to detect Btrfs root device."
  UUID=$(sudo blkid -s UUID -o value "$btrfs_device") ||
    fail "Failed to get UUID of Btrfs device."

  local fstab_entry="UUID=$UUID $SWAP_MOUNT_POINT btrfs defaults,nodatacow,noatime,subvol=$SWAP_SUBVOL 0 0"

  if ! grep -q "$fstab_entry" /etc/fstab; then
    echo -e "\n$fstab_entry\n" | sudo tee -a /etc/fstab ||
      fail "Failed to add swap subvolume mount to fstab."
    printc green "Swap subvolume mount added to fstab successfully."
  else
    printc yellow "Swap subvolume mount already exists in fstab."
  fi
}

configure_hibernation_support() {
  set_resume_offset
  configure_initramfs_resume_hook
}

set_resume_offset() {
  printc cyan "Configuring hibernation resume offset..."
  local resume_offset
  resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH") ||
    fail "Failed to get resume offset."

  echo "$resume_offset" | sudo tee /sys/power/resume_offset >/dev/null ||
    fail "Failed to get resume offset for hibernation."
  echo lz4 | sudo tee /sys/module/hibernate/parameters/compressor >/dev/null ||
    fail "Failed to set hibernation compressor."

  printc green "Hibernation support configured."
}

configure_initramfs_resume_hook() {
  printc cyan "Configuring initramfs for swap file..."
  if ! grep -q 'HOOKS=.*resume' "$MKINIT_CONF"; then
    printc cyan "Adding resume hook to mkinitcpio.conf..."
    sudo sed -i -E 's/^(HOOKS=.* )(udev|base)(.*)$/\1\2 resume\3/' "$MKINIT_CONF" ||
      fail "Failed to add resume hook to mkinitcpio.conf."
    printc green "Resume hook added to mkinitcpio.conf."
  else
    printc yellow "'resume' hook is already present."
  fi
}

setup_touchpad_udev_rule() {
  printc cyan "Setting up touchpad udev rule..."
  write_touchpad_udev_rule
  reload_udev_rules
}

write_touchpad_udev_rule() {
  printc cyan "Writing udev rule..."
  sudo tee "$TOUCHPAD_RULE_FILE" >/dev/null <<EOF || fail "Failed to write udev rule."
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF
  printc green "Touchpad udev rule written."
}

reload_udev_rules() {
  printc cyan "Reloading and triggering udev rules..."
  sudo udevadm control --reload-rules || fail "Failed to reload udev rules."
  sudo udevadm trigger || fail "Failed to trigger udev rules."
  printc green "Udev rules reloaded successfully."
}

enable_libinput_gestures() {
  printc cyan "Enabling libinput-gestures service..."
  if ! has_cmd "libinput-gestures"; then
    install_package "libinput-gestures"
  fi
  enable_service "libinput-gestures.service" "user"
}

setup_btrfs_swap() {
  printc cyan "Setting up Btrfs swap configuration..."
  create_btrfs_swap_subvolume
  add_swap_subvolume_to_fstab
  create_and_activate_swapfile
  add_swapfile_to_fstab
  configure_hibernation_support
}

# configure wake device through udev
wake_devices(){
  printc cyan "Configuring wake devices through udev..."
 sudo tee "$WAKE_DEVICES_RULE_FILE" >/dev/null <<EOF || fail "Failed to write wake devices udev rule."
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="0", RUN+="/usr/local/bin/toggle_wake_devices.sh disable"
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ENV{POWER_SUPPLY_ONLINE}=="1", RUN+="/usr/local/bin/toggle_wake_devices.sh enable"
EOF
  printc green "Wake devices udev rule written."
  reload_udev_rules
  printc green "Wake devices configured successfully."
}

main() {
  install_auto_cpufreq
  enable_auto_cpufreq_service

  if is_btrfs; then
    if confirm "Setup hibernation ?"; then
      setup_btrfs_swap
    else
      printc yellow "Skipping Btrfs swap setup."
    fi
  else
    printc yellow "Btrfs is not detected. Skipping Btrfs-specific swap setup."
  fi

  setup_touchpad_udev_rule
  enable_libinput_gestures
}

main
