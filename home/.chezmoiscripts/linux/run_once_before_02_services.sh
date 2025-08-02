#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================

common_init "hibernation setup"

# =============================================================================
# ENABLE SERVICES
# =============================================================================
print_box "smslant" "Services"
print_step "Enabling necessary services"

readonly USER_SERVICES=(
  gnome-keyring-daemon.service
  hypridle.service
  hyprsunset.service
  gcr-ssh-agent.socket
)

readonly SYSTEM_SERVICES=(
  bluetooth.service
  sddm.service
  ufw.service
)

# Enable services by scope
for scope in user system; do
  services=()
  if [[ "$scope" == "user" ]]; then
    services=("${USER_SERVICES[@]}")
  else
    services=("${SYSTEM_SERVICES[@]}")
  fi

  for service in "${services[@]}"; do
    enable_service "$service" "$scope"
  done
done

# Enable ufw
if sudo ufw enable >/dev/null 2>&1; then
  print_info "UFW enabled successfully"
else
  print_warning "Failed to enable UFW"
fi
