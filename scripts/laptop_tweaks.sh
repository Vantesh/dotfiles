#!/bin/bash

install_auto_cpufreq() {
  printc cyan "Checking auto-cpufreq installation..."

  if has_cmd auto-cpufreq; then
    printc green "auto-cpufreq is already installed."
    return 0
  fi

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

  sudo auto-cpufreq --install || fail "Failed to finalize auto-cpufreq installation."
  printc green "auto-cpufreq installed successfully."
}

enable_auto_cpufreq_service() {
  printc cyan "Enabling auto-cpufreq service..."
  enable_service "auto-cpufreq.service" "user"
}

create_btrfs_swap_subvolume() {
  printc cyan "Ensuring Btrfs subvolume for swap exists and is properly mounted..."

  local subvol_name="@swap"
  local subvol_path="/mnt/${subvol_name}"
  local mount_point="/swap"

  # Check if the subvolume exists
  if ! sudo btrfs subvolume list /mnt | grep -q "path ${subvol_name}$"; then
    sudo btrfs subvolume create "$subvol_path" || fail "Failed to create Btrfs subvolume for swap."
    printc green "Created Btrfs subvolume ${subvol_name}."
  else
    printc yellow "Btrfs subvolume ${subvol_name} already exists."
  fi

  # Ensure mount point exists
  sudo mkdir -p "$mount_point"

  # Mount the subvolume to /swap if not already mounted
  if ! mountpoint -q "$mount_point"; then
    sudo mount -o subvol=${subvol_name} /dev/your_btrfs_device "$mount_point" || fail "Failed to mount @swap at /swap."
    printc green "Mounted ${subvol_name} at ${mount_point}."
  else
    printc yellow "${mount_point} is already mounted."
  fi
}

create_and_activate_swapfile() {
  printc cyan "Creating swap file..."
  local swapsize=38G # Adjust this value based on your system's RAM size
  if [[ ! -f /swap/swapfile ]]; then
    btrfs filesystem mkswapfile --size "$swapsize" --uuid clear /swap/swapfile || fail "Failed to create swap file."
  else
    printc yellow "Swap file already exists."
  fi

  printc cyan "Activating swap file..."
  if ! swapon --show | grep -q "/swap/swapfile"; then
    sudo swapon /swap/swapfile || fail "Failed to activate swap file."
  else
    printc yellow "Swap file is already active."
  fi
}

add_swapfile_to_fstab() {
  printc cyan "Adding swap file to fstab..."
  if ! grep -q "/swap/swapfile" /etc/fstab; then
    echo "/swap/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab || fail "Failed to add swap file to fstab."
    printc green "Swap file added to fstab successfully."
  else
    printc yellow "Swap file already exists in fstab."
  fi
}

set_resume_offset() {
  local resume_offset
  resume_offset=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile)
  echo "$resume_offset" | sudo tee /sys/power/resume_offset
  echo lz4 | sudo tee /sys/module/hibernate/parameters/compressor
}

configure_initramfs_resume_hook() {
  printc cyan "Configuring initramfs for swap file..."
  local MKINIT_CONF="/etc/mkinitcpio.conf"
  if ! grep -q 'HOOKS=.*resume' "$MKINIT_CONF"; then
    printc cyan "Adding resume hook to mkinitcpio.conf..."
    sudo sed -i -E 's/^(HOOKS=.* )(udev|base)(.*)$/\1\2 resume\3/' "$MKINIT_CONF"
  else
    printc yellow "'resume' hook is already present."
  fi
}

setup_touchpad_udev_rule() {
  local UDEV_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"
  printc cyan "Writing udev rule..."
  sudo tee "$UDEV_RULE_FILE" >/dev/null <<EOF
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF
  printc cyan "Reloading and triggering udev rules..."
  sudo udevadm control --reload-rules
  sudo udevadm trigger
}

enable_libinput_gestures() {
  printc cyan "Enabling libinput-gestures service..."
  if ! has_cmd "libinput-gestures"; then
    install_package "libinput-gestures"
  fi
  enable_service "libinput-gestures.service" "user"
}

main() {
  # install_auto_cpufreq
  # enable_auto_cpufreq_service
  create_btrfs_swap_subvolume

  # create_and_activate_swapfile
  # add_swapfile_to_fstab
  # set_resume_offset
  # configure_initramfs_resume_hook
  # setup_touchpad_udev_rule
  # enable_libinput_gestures
}

main
