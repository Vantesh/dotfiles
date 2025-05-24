#!/bin/bash
# shellcheck disable=SC1091

BASE_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"

source "$LIB_DIR/utils.sh"

# Source dependencies arrays

source "$SCRIPTS_DIR/01_pacman_config.sh"
source "$SCRIPTS_DIR/02_install_yay.sh"
source "$SCRIPTS_DIR/03_dependencies.sh"
source "$SCRIPTS_DIR/04_fonts.sh"
source "$SCRIPTS_DIR/05_cursor_theme.sh"
source "$SCRIPTS_DIR/06_misc.sh"
source "$SCRIPTS_DIR/07_dotfiles.sh"

if confirm "Setup ZSH and related tools?"; then
  printc yellow "Starting ZSH setup..."

  source "$SCRIPTS_DIR/08_setup_zsh.sh"
else
  printc yellow "Skipping ZSH setup."
fi

if confirm "This is for limine bootloader setup. Do you want to continue?"; then
  printc yellow "Starting limine bootloader setup..."
  source "$SCRIPTS_DIR/09_limine_snapper.sh"
else
  printc yellow "Skipping limine bootloader setup."
fi
