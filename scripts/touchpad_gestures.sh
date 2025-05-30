#!/bin/bash
set -e

UDEV_RULE_FILE="/etc/udev/rules.d/90-touchpad-access.rules"

# Write the udev rule
printc cyan "Writing udev rule..."
sudo tee "$UDEV_RULE_FILE" >/dev/null <<EOF
KERNEL=="event*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
EOF

# Reload udev rules and trigger them
printc cyan "Reloading and triggering udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# enable libinput-gestures service
printc cyan "Enabling libinput-gestures service..."
if ! has_cmd "libinput-gestures"; then
  install_package "libinput-gestures"
fi
systemctl --user enable --now libinput-gestures.service

# Detect the touchpad input device
printc cyan "Detecting touchpad input device..."
EVENT_PATH=$(libinput list-devices 2>/dev/null | awk '/Touchpad/{f=1} f && /Kernel:/{print $2; exit}')

# Check if the user has ACL permissions
printc cyan "Checking access control list on $EVENT_PATH..."
if getfacl "$EVENT_PATH" | grep -q "$USER"; then
  printc green "User has proper ACL permissions on $EVENT_PATH"
else
  printc yellow "Log out and log back in to apply the changes."
fi
