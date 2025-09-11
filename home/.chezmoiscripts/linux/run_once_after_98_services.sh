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
  gnome-keyring-daemon
  hypridle
  mpris-proxy
)

readonly SYSTEM_SERVICES=(
  NetworkManager
  bluetooth
  udisks2
  ufw
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

print_step "Enabling UFW (Uncomplicated Firewall)"

if sudo ufw enable >/dev/null 2>&1; then
  print_info "UFW enabled"

  failed=()
  for port in 53317/udp 53317/tcp 443/tcp 80/tcp; do
    if sudo ufw allow "$port" >/dev/null 2>&1; then
      print_info "Allowed $port"
    else
      failed+=("$port")
    fi
  done

  if sudo ufw limit 22/tcp >/dev/null 2>&1; then
    print_info "Limited SSH (22/tcp)"
  else
    failed+=("22/tcp")
  fi

  if sudo ufw default deny incoming >/dev/null 2>&1; then
    print_info "Default: deny incoming"
  else
    print_warning "Failed to set deny incoming"
  fi

  if sudo ufw default allow outgoing >/dev/null 2>&1; then
    print_info "Default: allow outgoing"
  else
    print_warning "Failed to set allow outgoing"
  fi

  if ((${#failed[@]})); then
    print_warning "Failed rules: ${failed[*]}"
  fi
else
  print_warning "Failed to enable UFW"
fi

# Prevent systemd-networkd-wait-online timeout on boot
if systemctl is-active --quiet systemd-networkd-wait-online.service; then
  sudo systemctl disable systemd-networkd-wait-online.service
  sudo systemctl mask systemd-networkd-wait-online.service
fi

# updatedb
print_info "Running updatedb to update file database..."
if sudo updatedb; then
  print_info "updatedb completed successfully."
else
  print_warning "updatedb encountered issues."
fi
