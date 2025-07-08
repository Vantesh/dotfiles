#!/bin/bash

# Source helpers
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/home/.chezmoiscripts/.00_helpers.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly PACMAN_CONFIG="/etc/pacman.conf"
readonly PACMAN_BACKUP="${PACMAN_CONFIG}.bak"
readonly PACMAN_OPTIONS=("Color" "VerbosePkgLists" "ILoveCandy")

deps=(
  "pacman-contrib"
  "reflector"
)

for dep in "${deps[@]}"; do
  install_package "$dep"
done

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
  if sudo pacman -Syy --noconfirm &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
}

# =============================================================================
# PACCACHE CONFIGURATION
# =============================================================================

configure_paccache() {
  # Configure paccache arguments
  printc -n cyan "Configuring paccache arguments... "
  local paccache_config="/etc/conf.d/pacman-contrib"

  if update_config "$paccache_config" "PACCACHE_ARGS" "'-k1'"; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi

  # Enable and start paccache timer
  enable_service "paccache.timer" "system"
}

# =============================================================================
# HOOKS CONFIGURATION
# =============================================================================

pacman_hooks() {
  write_system_config "/etc/pacman.d/hooks/00-paccache.hook" "Paccache hook" <<EOF
[Trigger]
Type = Package
Operation = Remove
Operation = Install
Operation = Upgrade
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk1
Depends = pacman-contrib
EOF
  write_system_config "/etc/pacman.d/hooks/01-paccache-uninstalled.hook" "Paccache uninstalled hook" <<EOF
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache for uninstalled packages...
When = PostTransaction
Exec = /usr/bin/paccache -ruk0
Depends = pacman-contrib
EOF
}

# =============================================================================
# MIRRORLIST CONFIGURATION
# =============================================================================

update_mirrorlist() {

  # Backup current mirrorlist
  printc -n cyan "Backing up current mirrorlist... "
  if sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi

  # Update mirrorlist using reflector
  printc -n cyan "Generating new mirrorlist... "
  if sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null; then
    printc green "OK"
  else
    printc red "FAILED"
    # Restore backup on failure
    sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    return 1
  fi

  # Enable reflector timer for automatic updates
  enable_service "reflector.timer" "system"
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
  configure_paccache
  pacman_hooks

  if echo && confirm "Do you want to update mirrorlist?"; then
    update_mirrorlist
  else
    printc yellow "Skipping mirrorlist update."
  fi

  if echo && confirm "Do you want to setup Chaotic AUR repository?"; then
    setup_chaotic_aur
  else
    printc yellow "Skipping Chaotic AUR setup."
  fi
}

# Main execution
printc_box "PACMAN" "Configuring Pacman"
configure_pacman
