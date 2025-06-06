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

run_core_setup() {
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
  source "$SCRIPTS_DIR/enable_services.sh"
}

# =============================================================================
# OPTIONAL SETUP FUNCTIONS
# =============================================================================

setup_zsh() {
  if confirm "Setup ZSH and related tools?"; then
    printc_box "ZSH SETUP" "Configuring ZSH shell and tools"
    source "$SCRIPTS_DIR/zsh_setup.sh"
  else
    printc yellow "Skipping ZSH setup."
  fi
}

setup_limine_bootloader() {
  if confirm "This is for limine bootloader setup. Do you want to continue?"; then
    printc_box "LIMINE SETUP" "Configuring Limine bootloader and Snapper"
    source "$SCRIPTS_DIR/limine.sh"
  else
    printc yellow "Skipping limine bootloader setup."
  fi
}

setup_laptop_tweaks() {
  if confirm "Setup laptop tweaks?"; then
    printc_box "LAPTOP TWEAKS" "Applying laptop-specific optimizations"
    source "$SCRIPTS_DIR/laptop_tweaks.sh"
  else
    printc yellow "Skipping laptop tweaks setup."
  fi
}

reboot_system() {
  printc cyan "Rebooting system to apply changes..."
  sudo reboot
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  printc_box "WELCOME" "Arch Linux Dotfiles Setup"
  ensure_sudo
  run_core_setup
  setup_zsh
  setup_limine_bootloader
  setup_laptop_tweaks
  configure_services

  if confirm "Reboot system now to apply all changes?"; then
    reboot_system
  else
    printc yellow "Please remember to reboot your system later to apply all changes."
  fi
}

main
