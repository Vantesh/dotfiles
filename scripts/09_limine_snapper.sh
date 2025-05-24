#!/bin/bash

deps=(
  snapper
  snap-pac
  limine-mkinitcpio-hook
  limine-snapper-sync
  btrfs-assistant
  btrfs-progs
  sbctl
)

# Install dependencies with yay
if yay -S --needed --noconfirm "${deps[@]}"; then
  printc green "All dependencies installed successfully."
else
  fail "Failed to install dependencies."
fi

if systemctl is-active limine-snapper-sync.service &>/dev/null; then
  printc green "limine-snapper-sync service is already enabled."
else
  if systemctl enable limine-snapper-sync.service; then
    printc green "limine-snapper-sync service enabled successfully."
  else
    fail "Failed to enable limine-snapper-sync service."
  fi
fi

# copy  file in limine directory to /etc/default/limine
if sudo cp /etc/limine-snapper-sync.conf /etc/default/limine; then
  printc green "File copied successfully."
else
  fail "Failed to copy file."
fi
# edit the file to add snapshot number to 20
declare -A snapper_config=(
  ["MAX_SNAPSHOT_ENTRIES"]=20
  ["TERMINAL"]="kitty"
  ["TERMINAL_ARG"]="-e"
  ["ENABLE_UKI"]="yes"
  ["QUIET_MODE"]="yes"

)

for key in "${!snapper_config[@]}"; do
  value="${snapper_config[$key]}"
  line="${key}=${value}"

  # Check if key exists either commented or uncommented
  if grep -qE "^\s*#?\s*${key}=" /etc/default/limine; then
    # Update the line, uncomment if needed
    if sudo sed -i "s|^\s*#\?\s*${key}=.*|${line}|" /etc/default/limine; then
      printc green "Updated $key to $value"
    else
      fail "Failed to update $key"
    fi
  else
    # Key doesn't exist at all, add it on a new line
    if echo -e "\n$line" | sudo tee -a /etc/default/limine >/dev/null; then
      printc green "Added $key with value $value"
    else
      fail "Failed to add $key"
    fi
  fi
done
