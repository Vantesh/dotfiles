#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly PACMAN_CONFIG="/etc/pacman.conf"
readonly PACMAN_BACKUP="${PACMAN_CONFIG}.bak"
readonly PACMAN_OPTIONS=("Color" "VerbosePkgLists" "ILoveCandy")

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

  if sudo grep -q "^\s*$option\s*$" "$PACMAN_CONFIG"; then
    printc yellow "Exists"
  elif sudo grep -q "^\s*#\s*$option" "$PACMAN_CONFIG"; then
    sudo sed -i "s/^\s*#\s*${option}/${option}/" "$PACMAN_CONFIG" && printc green "OK"
  elif [[ "$option" == "ILoveCandy" ]]; then
    sudo sed -i "/^\s*Color/a $option" "$PACMAN_CONFIG" && printc green "OK"
  else
    printc yellow "not found"
  fi
}

# =============================================================================
# CHAOTIC AUR SETUP
# =============================================================================

setup_chaotic_aur() {
  printc cyan "Setting up Chaotic AUR repository..."

  # Install keyring and mirrorlist
  printc -n cyan "Installing Chaotic AUR keyring and mirrorlist... "
  if sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com &>/dev/null &&
    sudo pacman-key --lsign-key 3056513887B78AEB &>/dev/null &&
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi

  # Add repository to pacman.conf
  printc -n cyan "Adding Chaotic AUR to pacman.conf... "
  if ! sudo grep -q "\[chaotic-aur\]" "$PACMAN_CONFIG"; then
    if echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a "$PACMAN_CONFIG" >/dev/null; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already present"
  fi

  # Update package databases
  printc -n cyan "Updating package databases... "
  if sudo pacman -Sy --noconfirm &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
}

# =============================================================================
# MAIN CONFIGURATION FUNCTION
# =============================================================================

configure_pacman() {
  validate_pacman_config
  create_pacman_backup
  for option in "${PACMAN_OPTIONS[@]}"; do
    enable_pacman_option "$option"
  done

  echo
  if confirm "Do you want to setup Chaotic AUR repository?"; then
    setup_chaotic_aur
  else
    printc yellow "Skipping Chaotic AUR setup."
  fi

}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  configure_pacman

}

main
