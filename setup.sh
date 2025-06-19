#!/bin/bash
# shellcheck disable=SC1091

# =============================================================================
# CONSTANTS AND INITIALIZATION
# =============================================================================

BASE_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"

# Load utilities
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/utils.sh"

# =============================================================================
# CORE SETUP FUNCTIONS
# =============================================================================
initialize_environment() {
  clear
  printc -n cyan "Installing required applications..."
  apps=(
    "git"
    "gum"
  )

  missing_apps=()
  for app in "${apps[@]}"; do
    if ! has_cmd "$app"; then
      missing_apps+=("$app")
    fi
  done

  if [ ${#missing_apps[@]} -gt 0 ]; then
    if sudo pacman -S --noconfirm "${missing_apps[@]}" &>/dev/null; then
      printc green "OK"
    else
      fail "FAILED to install required applications"
    fi
  else
    printc green "Exists"
  fi

  # Check if running on TTY and configure console font
  if [[ $(tty) =~ ^/dev/tty[0-9]+$ ]]; then
    printc -n cyan "Installing and setting TTY console font..."
    if sudo pacman -S --noconfirm terminus-font &>/dev/null; then
      if sudo setfont ter-122b &>/dev/null; then
        printc green "OK"
      else
        printc yellow "Font installed but failed to set ter-124b"
      fi
    else
      printc yellow "Failed to install terminus-font"
    fi
  fi
}
run_core_setup() {
  printc_box "SUDO" "Configuring QOL sudo settings"
  source "$SCRIPTS_DIR/sudo_config.sh"
  printc_box "PACMAN" "Configuring Pacman"
  source "$SCRIPTS_DIR/pacman_config.sh"
  source "$SCRIPTS_DIR/AUR_helper.sh"
  printc_box "DEPENDENCIES" "Installing core dependencies and tools"
  source "$SCRIPTS_DIR/dependencies.sh"

  printc_box "THEMING" "Setting up Fonts, cursors and themes"
  source "$SCRIPTS_DIR/theming.sh"

  printc_box "DOTFILES SETUP" "Applying dotfiles and configurations"
  source "$SCRIPTS_DIR/dotfiles.sh"
}

configure_services() {
  printc_box "SYSTEM CONFIGURATION" "Configuring system settings and services"
  source "$SCRIPTS_DIR/services.sh"
}

# =============================================================================
# OPTIONAL SETUP FUNCTIONS
# =============================================================================

setup_zsh() {
  if echo && confirm "Setup ZSH and related tools?"; then
    printc_box "ZSH SETUP" "Configuring ZSH shell and tools"
    source "$SCRIPTS_DIR/zsh_setup.sh"
  else
    printc yellow "Skipping ZSH setup."
  fi
}
setup_snapper() {
  if echo && confirm "Setup Snapper for BTRFS snapshots?"; then
    printc_box "SNAPPER SETUP" "Configuring Snapper"
    source "$SCRIPTS_DIR/snapper_config.sh"
  else
    printc yellow "Skipping Snapper setup."
  fi
}
setup_laptop_tweaks() {
  if is_laptop; then
    printc_box "LAPTOP TWEAKS" "Applying laptop-specific tweaks"
    source "$SCRIPTS_DIR/laptop_tweaks.sh"
    if echo && confirm "Apply udev rules? (ONLY FOR PRECISION 5530)"; then
      printc -n cyan "Applying udev rules...."
      if sudo cp "$BASE_DIR/udev/"*.rules /etc/udev/rules.d/ && reload_udev_rules &>/dev/null; then
        printc green "OK"
      else
        fail "FAILED to apply udev rules."
      fi
    fi
  else
    printc yellow "Skipping laptop tweaks."
  fi
}

reboot_system() {
  if echo && confirm "Reboot the system to apply changes?"; then
    sudo reboot
  else
    printc yellow "You can reboot later to apply changes."
  fi

}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  if [[ $EUID -eq 0 ]]; then
    fail "This script should not be run as root. Please run it as a regular user."
  fi
  ensure_sudo
  initialize_environment
  run_core_setup
  setup_snapper
  setup_laptop_tweaks
  setup_zsh
  configure_services
  reboot_system
}

main
