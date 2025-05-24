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

enable_services() {
  local services=(
    "limine-snapper-sync.service"
    "snapper-timeline.timer"
    "snapper-cleanup.timer"
  )

  for service in "${services[@]}"; do
    if systemctl is-active "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      if sudo systemctl enable "$service"; then
        printc green "$service enabled successfully."
      else
        fail "Failed to enable $service."
      fi
    fi
  done
}
enable_services

# --- Snapper Config Values for /etc/default/limine ---
declare -A snapper_config=(
  ["MAX_SNAPSHOT_ENTRIES"]=20
  ["TERMINAL"]="kitty"
  ["TERMINAL_ARG"]="-e"
  ["ENABLE_UKI"]="yes"
)

CONFIG_FILE="/etc/default/limine"

for key in "${!snapper_config[@]}"; do
  update_or_append_config "$CONFIG_FILE" "$key" "${snapper_config[$key]}"
done

# --- Snapshots cleanup config ---
declare -A snapper_settings=(
  ["NUMBER_CLEANUP"]="yes"
  ["NUMBER_LIMIT"]="30"
  ["TIMELINE_CLEANUP"]="yes"
  ["TIMELINE_MIN_AGE"]="1800"
  ["TIMELINE_LIMIT_HOURLY"]="5"
  ["TIMELINE_LIMIT_DAILY"]="7"
  ["TIMELINE_LIMIT_WEEKLY"]="0"
  ["TIMELINE_LIMIT_MONTHLY"]="0"
  ["TIMELINE_LIMIT_YEARLY"]="0"
  ["EMPTY_PRE_POST_CLEANUP"]="yes"
  ["EMPTY_PRE_POST_MIN_AGE"]="3600"

)

for key in "${!snapper_settings[@]}"; do
  set_snapper_config_value "root" "$key" "${snapper_settings[$key]}"
done
