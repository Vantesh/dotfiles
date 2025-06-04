#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly PACMAN_CONFIG="/etc/pacman.conf"
readonly PACMAN_BACKUP="${PACMAN_CONFIG}.bak"
readonly PACMAN_OPTIONS=("Color" "VerbosePkgLists")

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_pacman_config() {
  printc cyan "Validating pacman configuration..."
  [[ -f "$PACMAN_CONFIG" ]] || fail "pacman.conf not found at $PACMAN_CONFIG. Aborting."
  printc green "pacman.conf found and accessible."
}

create_pacman_backup() {
  printc cyan "Creating backup of pacman.conf..."
  sudo cp "$PACMAN_CONFIG" "$PACMAN_BACKUP" || fail "Failed to backup pacman.conf. Aborting."
  printc green "Backup created at $PACMAN_BACKUP."
}

# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

enable_pacman_option() {
  local option="$1"

  if sudo grep -q "^\s*#\?\s*$option" "$PACMAN_CONFIG"; then
    sudo sed -i "s/^\s*#\?\s*${option}/${option}/" "$PACMAN_CONFIG" &&
      printc green "Enabled '${option}'" ||
      fail "Failed to enable '${option}'"
  else
    printc yellow "'${option}' already enabled or missing."
  fi
}

enable_pacman_options() {
  printc cyan "Enabling pacman options..."
  for option in "${PACMAN_OPTIONS[@]}"; do
    enable_pacman_option "$option"
  done
}

add_ilovecandy_option() {
  printc cyan "Adding ILoveCandy option..."
  if ! sudo grep -q "^\s*ILoveCandy" "$PACMAN_CONFIG"; then
    sudo sed -i "/^\s*Color/a ILoveCandy" "$PACMAN_CONFIG" &&
      printc green "Inserted 'ILoveCandy'" ||
      fail "Failed to insert 'ILoveCandy'"
  else
    printc yellow "'ILoveCandy' already present."
  fi
}

# =============================================================================
# MAIN CONFIGURATION FUNCTION
# =============================================================================

configure_pacman() {
  printc cyan "Configuring pacman..."

  validate_pacman_config
  create_pacman_backup
  enable_pacman_options
  add_ilovecandy_option

  printc green "pacman configuration completed successfully."
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  configure_pacman
}

main
