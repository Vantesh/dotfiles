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
  for dep in "${DEPENDENCIES[@]}"; do
    install_package "$dep"
  done
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

enable_snapper_services() {
  for service in "${SERVICES[@]}"; do
    enable_service "$service" "system"
  done
}

# =============================================================================
# LIMINE CONFIGURATION
# =============================================================================

setup_limine_config_file() {
  printc -n cyan "Setting up Limine config... "
  if [[ ! -f "$LIMINE_CONFIG_FILE" ]]; then
    if sudo cp "$LIMINE_CONFIG_TEMPLATE" "$LIMINE_CONFIG_FILE"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    printc yellow "already exists"
  fi
}

configure_limine_settings() {
  printc -n cyan "Configuring Limine settings... "
  declare -A snapper_config=(
    ["MAX_SNAPSHOT_ENTRIES"]=20
    ["TERMINAL"]="kitty"
    ["TERMINAL_ARG"]="-e"
    ["ENABLE_UKI"]="yes"
  )

  local success=true
  for key in "${!snapper_config[@]}"; do
    if ! update_config "$LIMINE_CONFIG_FILE" "$key" "${snapper_config[$key]}"; then
      success=false
      break
    fi
  done

  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# SNAPPER CONFIGURATION
# =============================================================================

configure_snapper_cleanup() {
  printc -n cyan "Configuring Snapper cleanup... "
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

  local success=true
  for key in "${!snapper_settings[@]}"; do
    if ! set_snapper_config_value "root" "$key" "${snapper_settings[$key]}"; then
      success=false
      break
    fi
  done

  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  install_dependencies
  enable_snapper_services
  setup_limine_config_file
  configure_limine_settings
  configure_snapper_cleanup
  echo
  printc green "Limine and Snapper setup completed"
}

main
