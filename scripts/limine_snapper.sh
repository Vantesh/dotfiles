#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DEPENDENCIES=(
  snapper
  snap-pac
  limine-mkinitcpio-hook
  limine-snapper-sync
  btrfs-assistant
  btrfs-progs
  sbctl
)

readonly SERVICES=(
  "limine-snapper-sync.service"
  "snapper-timeline.timer"
  "snapper-cleanup.timer"
)

readonly LIMINE_CONFIG_FILE="/etc/default/limine"
readonly LIMINE_CONFIG_TEMPLATE="/etc/limine-snapper-sync.conf"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  printc cyan "Installing Limine and Snapper dependencies..."
  for dep in "${DEPENDENCIES[@]}"; do
    install_package "$dep"
  done
  printc green "Dependencies installed successfully."
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

enable_snapper_services() {
  printc cyan "Enabling Snapper services..."
  for service in "${SERVICES[@]}"; do
    enable_service "$service" "system"
  done
  printc green "Snapper services enabled successfully."
}

# =============================================================================
# LIMINE CONFIGURATION
# =============================================================================

setup_limine_config_file() {
  printc cyan "Setting up Limine configuration file..."
  if [[ ! -f "$LIMINE_CONFIG_FILE" ]]; then
    sudo cp "$LIMINE_CONFIG_TEMPLATE" "$LIMINE_CONFIG_FILE" || fail "Failed to copy Limine configuration template."
    printc green "Limine configuration file created."
  else
    printc yellow "Limine configuration file already exists."
  fi
}

configure_limine_settings() {
  printc cyan "Configuring Limine settings..."
  declare -A snapper_config=(
    ["MAX_SNAPSHOT_ENTRIES"]=20
    ["TERMINAL"]="kitty"
    ["TERMINAL_ARG"]="-e"
    ["ENABLE_UKI"]="yes"
  )

  for key in "${!snapper_config[@]}"; do
    update_config "$LIMINE_CONFIG_FILE" "$key" "${snapper_config[$key]}"
  done
  printc green "Limine settings configured successfully."
}

# =============================================================================
# SNAPPER CONFIGURATION
# =============================================================================

configure_snapper_cleanup() {
  printc cyan "Configuring Snapper cleanup settings..."
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
  printc green "Snapper cleanup settings configured successfully."
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  install_dependencies
  enable_snapper_services
  setup_limine_config_file
  configure_limine_settings
  configure_snapper_cleanup

  printc green "Limine and Snapper setup completed successfully."
}

main
