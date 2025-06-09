#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

DEPS=(
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
  "snapper-cleanup.timer"
)

readonly LIMINE_CONFIG_FILE="/etc/default/limine"
readonly LIMINE_CONFIG_TEMPLATE="/etc/limine-snapper-sync.conf"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  for dep in "${DEPS[@]}"; do
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
    ["MAX_SNAPSHOT_ENTRIES"]=15
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
    ["NUMBER_LIMIT"]="20"
    ["TIMELINE_CREATE"]="no"
    ["TIMELINE_CLEANUP"]="yes"
    ["TIMELINE_MIN_AGE"]="1800"
    ["TIMELINE_LIMIT_HOURLY"]="5"
    ["TIMELINE_LIMIT_DAILY"]="7"
    ["TIMELINE_LIMIT_WEEKLY"]="0"
    ["TIMELINE_LIMIT_MONTHLY"]="0"
    ["TIMELINE_LIMIT_YEARLY"]="0"
    ["EMPTY_PRE_POST_CLEANUP"]="yes"
    ["EMPTY_PRE_POST_MIN_AGE"]="1800"
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
# PLYMOUTH CONFIGURATION
# =============================================================================

setup_plymouth() {
  printc cyan "Setting up Plymouth..."

  install_package "plymouth"

  printc -n cyan "Configuring Plymouth hooks... "
  local mkinitcpio_conf="/etc/mkinitcpio.conf"

  if ! grep -q "plymouth" "$mkinitcpio_conf"; then
    if sudo sed -i 's/\(HOOKS=.*\) encrypt \(.*\)/\1 plymouth-encrypt \2/' "$mkinitcpio_conf" &&
      sudo sed -i 's/\(HOOKS=.*\) \(.*\) filesystems \(.*\)/\1 \2 plymouth filesystems \3/' "$mkinitcpio_conf"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already configured"
  fi

  printc -n cyan "Regenerating initramfs... "
  if sudo limine-update &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
}

configure_kernel_parameters() {
  printc -n cyan "Configuring kernel parameters... "
  local limine_conf="/etc/limine-entry-tool.conf"

  if [[ ! -f "$limine_conf" ]]; then
    printc yellow "Limine config not found"
    return 1
  fi

  # Check if quiet and splash are already present
  if grep -q "quiet.*splash\|splash.*quiet" "$limine_conf"; then
    printc yellow "already configured"
    return 0
  fi

  # Get current KERNEL_CMDLINE value and append quiet splash
  if grep -q "^KERNEL_CMDLINE\[default\]=" "$limine_conf"; then
    # Append to existing KERNEL_CMDLINE
    sudo sed -i '/^KERNEL_CMDLINE\[default\]=/s/"$/ quiet splash"/' "$limine_conf" && printc green "OK"
  elif grep -q "^#KERNEL_CMDLINE\[default\]=" "$limine_conf"; then
    # Uncomment and set with quiet splash
    sudo sed -i 's/^#KERNEL_CMDLINE\[default\]=""/KERNEL_CMDLINE[default]="quiet splash"/' "$limine_conf" && printc green "OK"
  else
    # Add new KERNEL_CMDLINE entry
    echo 'KERNEL_CMDLINE[default]="quiet splash"' | sudo tee -a "$limine_conf" >/dev/null && printc green "OK"
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

  if confirm "Install and configure Plymouth for boot splash?"; then
    setup_plymouth
    configure_kernel_parameters
  else
    printc yellow "Skipping Plymouth setup."
  fi
}

main
