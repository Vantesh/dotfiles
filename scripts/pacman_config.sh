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
  [[ -f "$PACMAN_CONFIG" ]] || fail "pacman.conf not found at $PACMAN_CONFIG"
}

create_pacman_backup() {
  printc -n cyan "Backing up pacman.conf... "
  if sudo cp "$PACMAN_CONFIG" "$PACMAN_BACKUP"; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

enable_pacman_option() {
  local option="$1"
  printc -n cyan "Enabling $option... "

  if sudo grep -q "^\s*#\?\s*$option" "$PACMAN_CONFIG"; then
    if sudo sed -i "s/^\s*#\?\s*${option}/${option}/" "$PACMAN_CONFIG"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already enabled"
  fi
}

enable_pacman_options() {
  for option in "${PACMAN_OPTIONS[@]}"; do
    enable_pacman_option "$option"
  done
}

add_ilovecandy_option() {
  printc -n cyan "Adding ILoveCandy... "
  if ! sudo grep -q "^\s*ILoveCandy" "$PACMAN_CONFIG"; then
    if sudo sed -i "/^\s*Color/a ILoveCandy" "$PACMAN_CONFIG"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already present"
  fi
}

# =============================================================================
# MAIN CONFIGURATION FUNCTION
# =============================================================================

configure_pacman() {
  validate_pacman_config
  create_pacman_backup
  enable_pacman_options
  add_ilovecandy_option
  echo
  printc green "pacman configuration completed successfully."
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  configure_pacman
}

main
