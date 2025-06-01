#!/bin/bash

enable_services() {
  local user_services=(
    hyprpolkitagent.service
    gnome-keyring-daemon.service
    waybar.service
    hypridle.service
    hyprpaper.service
    swaync.service
  )
  local system_services=(
    bluetooth.service
    paccache.timer
    sddm.service
    systemd-resolved.service
    ufw.service
  )

  for service in "${user_services[@]}"; do
    if systemctl --user is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      systemctl --user enable --now "$service" || fail "Failed to enable $service."
    fi
  done

  for service in "${system_services[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      sudo systemctl enable --now "$service" || fail "Failed to enable $service."
    fi
  done
}

enable_services

# enable ufw firewall
sudo ufw enable || fail "Failed to enable UFW firewall."

# setup systemd-resolved
if confirm "Configure systemd-resolved?"; then
  sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  # create resolved.conf.d directory if it doesn't exist
  if [ ! -d /etc/systemd/resolved.conf.d ]; then
    sudo mkdir -p /etc/systemd/resolved.conf.d
  fi
  # add dns_over_tls configuration
  if [ ! -f /etc/systemd/resolved.conf.d/dns_over_tls.conf ]; then
    sudo tee /etc/systemd/resolved.conf.d/dns.conf >/dev/null <<EOF
[Resolve]
# Some examples of DNS servers which may be used for DNS= and FallbackDNS=:
# Cloudflare: 1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com
# Google:     8.8.8.8#dns.google 8.8.4.4#dns.google 2001:4860:4860::8888#dns.google 2001:4860:4860::8844#dns.google
# Quad9:      9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net

DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com

#falback DNS servers are used when the DNS servers specified in DNS= are not reachable.
FallbackDNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net 8.8.8.8#dns.google 2606:4700:4700::1111#cloudflare-dns.com 2620:fe::9#dns.quad9.net 2001:4860:4860::8888#dns.google

DNSOverTLS=yes
Domains=~.

# Enable DNSSEC validation
DNSSEC=allow-downgrade
EOF

  fi
fi
