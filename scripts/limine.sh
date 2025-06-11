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
readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"
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

  if [[ -f "$LIMINE_CONFIG_FILE" ]]; then
    printc yellow "exists"
    return 0
  fi

  if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" || ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
    printc red "FAILED - Missing template(s)"
    return 1
  fi

  if cat "$LIMINE_ENTRY_TEMPLATE" "$LIMINE_SNAPPER_TEMPLATE" | sudo tee "$LIMINE_CONFIG_FILE" >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
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
    if sudo sed -i '/^HOOKS=/ s/\(.*\) filesystems \(.*\)/\1 plymouth filesystems \2/' "$mkinitcpio_conf"; then
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

  if [[ ! -f "$LIMINE_CONFIG_FILE" ]]; then
    printc yellow "Limine config not found"
    return 1
  fi

  # Check if quiet and splash are already present
  if grep -q "quiet.*splash\|splash.*quiet" "$LIMINE_CONFIG_FILE"; then
    printc yellow "already configured"
    return 0
  fi

  # Get current KERNEL_CMDLINE value and append quiet splash
  if grep -q "^KERNEL_CMDLINE\[default\]=" "$LIMINE_CONFIG_FILE"; then
    # Append to existing KERNEL_CMDLINE
    sudo sed -i '/^KERNEL_CMDLINE\[default\]=/s/"$/ quiet loglevel=3 splash"/' "$LIMINE_CONFIG_FILE" && printc green "OK"
  elif grep -q "^#KERNEL_CMDLINE\[default\]=" "$LIMINE_CONFIG_FILE"; then
    # Uncomment and set with quiet splash
    sudo sed -i 's/^#KERNEL_CMDLINE\[default\]=""/KERNEL_CMDLINE[default]="quiet loglevel=3 splash"/' "$LIMINE_CONFIG_FILE" && printc green "OK"
  else
    # Add new KERNEL_CMDLINE entry
    echo 'KERNEL_CMDLINE[default]="quiet loglevel=3 splash"' | sudo tee -a "$LIMINE_CONFIG_FILE" >/dev/null && printc green "OK"
  fi
}

# =============================================================================
# LIMINE INTERFACE CONFIGURATION
# =============================================================================

configure_limine_interface() {
  printc cyan "Configuring Limine interface..."

  local limine_conf="/boot/limine.conf"

  if [[ ! -f "$limine_conf" ]]; then
    printc red "Limine config file not found at $limine_conf"
    return 1
  fi

  printc -n cyan "Setting interface options... "

  # Interface configuration parameters
  local PARAMS=(
    "term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_palette_bright: 585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_background: 1e1e2e"
    "term_foreground: cdd6f4"
    "term_background_bright: 1e1e2e"
    "term_foreground_bright: cdd6f4"
    "timeout: 2"
    "default_entry: 2"
    "interface_branding: Arch Linux"

  )

  # Build interface configuration block
  local interface_config=$'\n# Interface Configuration\n'
  for param in "${PARAMS[@]}"; do
    interface_config+="$param"$'\n'
  done

  # Find the line with "/+Arch Linux" and insert interface config above it
  if grep -q "/+Arch Linux" "$limine_conf"; then
    # Create a temporary file with the interface config inserted
    if awk -v config="$interface_config" '
      /\/\+Arch Linux/ {
        print config
        print $0
        next
      }
      # Skip existing interface config lines if they exist
      /^term_palette:|^term_palette_bright:|^term_background:|^term_foreground:|^term_background_bright:|^term_foreground_bright:|^timeout:|^wallpaper:|^interface_branding:|^default_entry:/ {
        next
      }
      { print }
    ' "$limine_conf" | sudo tee "${limine_conf}.tmp" >/dev/null && sudo mv "${limine_conf}.tmp" "$limine_conf"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "Arch Linux entry not found in $limine_conf"
    return 1
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

  if confirm "Configure Limine interface settings?"; then
    configure_limine_interface
  else
    printc yellow "Skipping Limine interface configuration."
  fi

  if confirm "Install and configure Plymouth for boot splash?"; then
    setup_plymouth
    configure_kernel_parameters
  else
    printc yellow "Skipping Plymouth setup."
  fi
}

main
