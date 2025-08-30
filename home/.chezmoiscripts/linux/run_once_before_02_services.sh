#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

# =============================================================================
# Initialize Environment
# =============================================================================

common_init

# =============================================================================
# ENABLE SERVICES
# =============================================================================
print_box "smslant" "Services"
print_step "Enabling necessary services"

readonly USER_SERVICES=(
  gnome-keyring-daemon.service
  hypridle.service
)

readonly SYSTEM_SERVICES=(
  bluetooth.service
  udisks2.service
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
print_step "Enabling UFW (Uncomplicated Firewall)"
if sudo ufw enable >/dev/null 2>&1; then
  print_info "UFW enabled successfully"
  # Allow ports for LocalSend
  if sudo ufw allow 53317/udp >/dev/null 2>&1 && sudo ufw allow 53317/tcp >/dev/null 2>&1; then
    print_info "Allowed ports for LocalSend"
  else
    print_warning "Failed to allow ports for LocalSend"
  fi

  if sudo ufw allow 22/tcp >/dev/null 2>&1; then
    print_info "Allowed SSH port 22"
  else
    print_warning "Failed to allow SSH port 22"
  fi

else
  print_warning "Failed to enable UFW"
fi
