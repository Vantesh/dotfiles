#!/bin/bash
auto_cpufreq() {
  printc cyan "Installing auto-cpu freq..."

  if ! has_cmd auto-cpufreq; then
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
  else
    printc green "auto-cpufreq is already installed."
  fi
}

auto_cpufreq

# Enable auto-cpufreq service
printc cyan "Enabling auto-cpufreq service..."
if ! systemctl --user is-active auto-cpufreq.service >/dev/null 2>&1; then
  sudo systemctl enable --now auto-cpufreq.service || fail "Failed to enable auto-cpufreq service."
  printc green "auto-cpufreq service enabled and started."
else
  printc yellow "auto-cpufreq service is already active."
fi

# create btrfs subvolume for swap
printc cyan "Creating btrfs subvolume for swap..."
if ! btrfs subvolume list / | grep -q "swap"; then
  sudo btrfs subvolume create /mnt/@swap || fail "Failed to create btrfs subvolume for swap."
  printc green "Btrfs subvolume for swap created successfully."
else
  printc yellow "Btrfs subvolume for swap already exists."
fi

# mount the swap subvolume
root_device=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
if ! mountpoint -q /swap; then
  printc cyan "Mounting @swap subvolume..."
  sudo mkdir -p /swap
  sudo mount -o subvol=@swap "$root_device" /swap || fail "Failed to mount @swap subvolume to /swap."
else
  printc yellow "/swap is already mounted."
fi

# create swap file
printc cyan "Creating swap file..."
swapsize=38G # Adjust this value based on your system's RAM size
btrfs filesystem mkswapfile --size "$swapsize" --uuid clear /swap/swapfile || fail "Failed to create swap file."

# activate the swap file
printc cyan "Activating swap file..."
sudo swapon /swap/swapfile || fail "Failed to activate swap file."

# add swap file to fstab
printc cyan "Adding swap file to fstab..."
if ! grep -q "/swap/swapfile" /etc/fstab; then
  echo "/swap/swapfile none swap defaults 0 0" | sudo tee -a /etc/fstab || fail "Failed to add swap file to fstab."
  printc green "Swap file added to fstab successfully."
else
  printc yellow "Swap file already exists in fstab."
fi

# add resume_offset
resume_offset=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile)
echo "$resume_offset" | sudo tee /sys/power/resume_offset
echo lz4 | sudo tee /sys/module/hibernate/parameters/compressor

# configure initramfs
printc cyan "Configuring initramfs for swap file..."
MKINIT_CONF="/etc/mkinitcpio.conf"
if ! grep -q 'HOOKS=.*resume' "$MKINIT_CONF"; then
  printc cyan "Adding resume hook to mkinitcpio.conf..."
  sudo sed -i -E 's/^(HOOKS=.* )(udev|base)(.*)$/\1\2 resume\3/' "$MKINIT_CONF"
else
  echo "'resume' hook is already present."
fi
