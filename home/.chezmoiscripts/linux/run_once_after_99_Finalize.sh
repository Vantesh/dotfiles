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
print_step "Setup complete. Rebooting system in 10 seconds. Press Ctrl+C to cancel."
canceled=false
trap 'canceled=true' INT

for i in {10..1}; do
  printf "\rRebooting in %s... Press Ctrl+C to cancel." "$i"
  sleep 1 || true
  if [ "$canceled" = true ]; then
    break
  fi
done
echo
trap - INT

if [ "$canceled" = true ]; then
  print_warning "Reboot canceled. You can reboot later to apply changes."
else
  reboot
fi
