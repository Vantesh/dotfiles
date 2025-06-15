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
  apps=(
    "git"
    "gum"
  )
  for app in "${apps[@]}"; do
    if ! has_cmd "$app"; then
      printc -n cyan "Initializing environment..."
      if sudo pacman -S --noconfirm "$app" &>/dev/null; then
        printc green "OK"
      else
        fail "FAILED to install $app"
      fi

    fi
  done
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
  if confirm "Setup ZSH and related tools?"; then
    printc_box "ZSH SETUP" "Configuring ZSH shell and tools"
    source "$SCRIPTS_DIR/zsh_setup.sh"
  else
    printc yellow "Skipping ZSH setup."
  fi
}

setup_limine_bootloader() {
  if detect_limine_bootloader; then
    printc_box "LIMINE BOOTLOADER" "Configuring Limine bootloader"
    source "$SCRIPTS_DIR/limine.sh"
  else
    printc yellow "Limine bootloader not detected. Skipping setup."
  fi
}

setup_laptop_tweaks() {
  if is_laptop; then
    printc_box "LAPTOP TWEAKS" "Applying laptop-specific tweaks"
    source "$SCRIPTS_DIR/laptop_tweaks.sh"
    if confirm "Apply udev rules? (ONLY FOR PRECISION 5530)"; then
      printc -n cyan "Applying udev rules...."
      if sudo cp "$SCRIPTS_DIR/udev/rules.d/"*.rules /etc/udev/rules.d/ && reload_udev_rules &>/dev/null; then
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
  if confirm "Reboot the system to apply changes?"; then
    sudo reboot
  else
    printc yellow "You can reboot later to apply changes."
  fi

}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  ensure_sudo
  initialize_environment
  run_core_setup
  setup_zsh
  setup_limine_bootloader
  setup_laptop_tweaks
  configure_services
  reboot_system
}

main
