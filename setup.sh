#!/bin/bash
# shellcheck disable=SC1091

# =============================================================================
# CONSTANTS
# =============================================================================

readonly BASE_DIR
BASE_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly SCRIPTS_DIR="$BASE_DIR/scripts"
readonly LIB_DIR="$SCRIPTS_DIR/lib"

# =============================================================================
# INITIALIZATION
# =============================================================================

initialize_environment() {
  printc cyan "Initializing setup environment..."
  source "$LIB_DIR/utils.sh"
  printc green "Environment initialized successfully."
}

# =============================================================================
# CORE SETUP FUNCTIONS
# =============================================================================

run_core_setup() {
  printc cyan "Running core system setup..."

  source "$SCRIPTS_DIR/pacman_config.sh"
  source "$SCRIPTS_DIR/AUR_helper.sh"
  source "$SCRIPTS_DIR/dependencies.sh"
  source "$SCRIPTS_DIR/theming.sh"
  source "$SCRIPTS_DIR/enable_services.sh"
  source "$SCRIPTS_DIR/dotfiles.sh"

  printc green "Core setup completed successfully."
}

# =============================================================================
# OPTIONAL SETUP FUNCTIONS
# =============================================================================

setup_zsh() {
  if confirm "Setup ZSH and related tools?"; then
    printc cyan "Starting ZSH setup..."
    source "$SCRIPTS_DIR/zsh_setup.sh"
  else
    printc yellow "Skipping ZSH setup."
  fi
}

setup_limine_bootloader() {
  if confirm "This is for limine bootloader setup. Do you want to continue?"; then
    printc cyan "Starting limine bootloader setup..."
    source "$SCRIPTS_DIR/limine_snapper.sh"
  else
    printc yellow "Skipping limine bootloader setup."
  fi
}

setup_laptop_tweaks() {
  if confirm "Setup laptop tweaks?"; then
    printc cyan "Starting laptop tweaks setup..."
    source "$SCRIPTS_DIR/laptop_tweaks.sh"
  else
    printc yellow "Skipping laptop tweaks setup."
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  printc cyan "Starting dotfiles setup..."

  initialize_environment
  run_core_setup
  setup_zsh
  setup_limine_bootloader
  setup_laptop_tweaks

  printc green "Setup completed successfully!"
}

main
