#!/bin/bash

enable_services() {
  local user_services=(
    hyprpolkitagent.service
    gnome-keyring-daemon.socket
    waybar.service
    hypridle.service
    hyprpaper.service
  )
  local system_services=(
    bluetooth.service
    paccache.timer
    sddm.service
    ufw.service
  )

  for service in "${user_services[@]}"; do
    if systemctl --user is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      systemctl --user enable "$service" || fail "Failed to enable $service."
    fi
  done

  for service in "${system_services[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      sudo systemctl enable "$service" || fail "Failed to enable $service."
    fi
  done
}

enable_services
