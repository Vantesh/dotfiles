#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

# ===============================================================================
# FINALIZE
# ===============================================================================
print_box "smslant" "Setup Complete"
printf "\n"

# Reboot Prompt
if confirm "Would you like to reboot now?"; then
  print_info "Rebooting..."
  systemctl reboot
else
  print_info "Please reboot at your earliest convenience to ensure all changes take effect."
fi
