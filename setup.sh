#!/bin/bash
# shellcheck disable=SC1091

BASE_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"

source "$LIB_DIR/utils.sh"

source "$SCRIPTS_DIR/pacman_config.sh"
source "$SCRIPTS_DIR/AUR_helper.sh"
source "$SCRIPTS_DIR/dependencies.sh"
source "$SCRIPTS_DIR/theming.sh"
source "$SCRIPTS_DIR/enable_services.sh"
source "$SCRIPTS_DIR/dotfiles.sh"

if confirm "Setup ZSH and related tools?"; then
  printc cyan "Starting ZSH setup..."

  source "$SCRIPTS_DIR/zsh_setup.sh"
else
  printc yellow "Skipping ZSH setup."

fi

if confirm "This is for limine bootloader setup. Do you want to continue?"; then
  printc cyan "Starting limine bootloader setup..."
  source "$SCRIPTS_DIR/limine_snapper.sh"
else
  printc yellow "Skipping limine bootloader setup."
fi

if confirm "Setup laptop tweaks?"; then
  printc cyan "Starting laptop tweaks setup..."
  source "$SCRIPTS_DIR/laptop_tweaks.sh"
else
  printc yellow "Skipping laptop tweaks setup."
fi
