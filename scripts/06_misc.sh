#!/bin/bash
auto_cpufreq() {
  printc yellow "Running miscellaneous setup tasks..."

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
    auto-cpufreq.service
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
