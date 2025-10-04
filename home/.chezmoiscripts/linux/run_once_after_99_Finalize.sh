#!/usr/bin/env bash
# 99_Finalize.sh - Finalization script to be run once after all other scripts

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

print_box "Setup Complete"
printf "\n"

# Reboot Prompt
if confirm "Would you like to reboot now?"; then
  log INFO "Rebooting system..."
  systemctl reboot
else
  log INFO "Reboot skipped. Please reboot manually later to apply all changes."
fi
