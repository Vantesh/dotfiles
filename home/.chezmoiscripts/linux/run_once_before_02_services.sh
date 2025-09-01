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
  NetworkManager
  bluetooth.service
  udisks2.service
  ufw.service
  reflector.timer
  pacman-filesdb-refresh.timer
  paccache.timer
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
  print_info "UFW enabled"

  ports=("53317/udp" "53317/tcp" "22/tcp")
  failed=()
  for port in "${ports[@]}"; do
    if sudo ufw allow "$port" >/dev/null 2>&1; then
      print_info "Allowed $port"
    else
      failed+=("$port")
    fi
  done

  if ((${#failed[@]})); then
    print_warning "Failed to allow: ${failed[*]}"
  fi
else
  print_warning "Failed to enable UFW"
fi

# Prevent systemd-networkd-wait-online timeout on boot
if systemctl is-active --quiet systemd-networkd-wait-online.service; then
  sudo systemctl disable systemd-networkd-wait-online.service
  sudo systemctl mask systemd-networkd-wait-online.service
fi
