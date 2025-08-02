#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

readonly GRUB_THEME_URL="https://github.com/semimqmo/sekiro_grub_theme"
readonly QUIET_FLAGS_HOOKS="quiet loglevel=3 splash vt.global_cursor_default=0 nowatchdog rd.udev.log_level=3"

#===================================================================================
# SDDM
#===================================================================================
print_box "smslant" "SDDM"
print_step "Setting up SDDM theme"

write_system_config "/etc/sddm.conf.d/10-wayland.conf" "SDDM wayland configuration" <<EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF

write_system_config "/etc/sddm.conf.d/hidpi.conf" "SDDM HiDPI configuration" <<EOF
[Wayland]
EnableHiDPI=true
EOF

# copy stray theme files
if sudo cp -r "${CHEZMOI_WORKING_TREE}/assets/sddm/stray" /usr/share/sddm/themes/; then
  sudo chmod -R 755 /usr/share/sddm/themes/stray
  print_info "SDDM theme files copied successfully"

  write_system_config "/etc/sddm.conf.d/theme.conf" "SDDM theme" <<EOF
[Theme]
Current=stray
EOF
  print_info "SDDM theme set to Stray"

else
  print_error "Failed to copy SDDM theme files"
fi

# ===================================================================================
# BOOTLOADER THEME
# ===================================================================================

if [[ $(detect_bootloader) == "grub" ]]; then
  print_box "smslant" "GRUB"
  print_step "Setting up GRUB theme"

  if [[ -d "/usr/share/grub/themes/Sekiro" ]]; then
    print_warning "GRUB theme already exists, skipping download"

  else
    print_info "Installing GRUB theme"

    temp_dir=$(mktemp -d)
    if git clone "${GRUB_THEME_URL}" "$temp_dir" >/dev/null 2>&1; then
      if cd "$temp_dir" && sudo ./install.sh >/dev/null 2>&1; then
        print_info "GRUB theme installed successfully"
        cd - >/dev/null || true
        rm -rf "$temp_dir"
      fi
    fi

  fi
fi

if [[ $(detect_bootloader) == "limine" ]] && ! grep -q "CachyOS" /etc/os-release; then
  print_box "smslant" "Limine"
  print_step "Setting up Limine theme"

  limine_conf="/boot/limine.conf"
  THEME_BLOCK=$(
    cat <<'EOF'
# catppuccin mocha theme for limine
timeout: 1
default_entry: 2
interface_branding:
term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4
term_palette_bright: 585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4
term_background: 1e1e2e
term_foreground: cdd6f4
term_background_bright: 1e1e2e
term_foreground_bright: cdd6f4
EOF
  )

  if grep -iq "term_palette=" "$limine_conf"; then
    print_warning "Limine theme settings already exist."
  else
    if create_backup "$limine_conf"; then
      sudo sed -i -E \
        -e '/^\s*#*\s*(timeout|default_entry|interface_branding|term_palette|term_palette_bright|term_background|term_foreground|term_background_bright|term_foreground_bright)\s*[:=].*/Id' \
        -e '/^\s*#*\s*catppuccin mocha theme for limine/Id' \
        "$limine_conf"

      # Create a temporary file to safely store the new content
      temp_file=$(mktemp)

      # Use awk to generate the new content and save it to the temp file
      awk -v block="$THEME_BLOCK" '
        BEGIN { inserted=0 }
        {
          if (!inserted && $0 ~ /^\/\+Arch Linux/) {
            print "";
            print block;
            print "";
            inserted=1
          }
          print
        }
      ' "$limine_conf" >"$temp_file"

      # If awk succeeded, write the new content to the original file.
      if [[ -s "$temp_file" ]]; then
        sudo cat "$temp_file" | sudo tee "$limine_conf" >/dev/null
        rm "$temp_file"
        print_info "Limine theme has been added successfully."
      else
        print_error "Failed to generate new limine.conf. No changes made."
        rm "$temp_file"
      fi
    fi
  fi
fi
#===================================================================================
# Plymouth
#===================================================================================
print_box "smslant" "Plymouth"
print_step "Setting up Plymouth"

mkinitcpio_conf="/etc/mkinitcpio.conf"
config_changed=false

print_info "Checking mkinitcpio hooks for plymouth..."

if ! sudo grep -qE '^\s*HOOKS=.*\bplymouth\b' "$mkinitcpio_conf"; then
  print_info "Adding 'plymouth' hook to $mkinitcpio_conf..."
  # This sed command safely inserts 'plymouth' before 'filesystems'
  if sudo sed -i '/^HOOKS=/ s/filesystems/plymouth filesystems/' "$mkinitcpio_conf"; then
    config_changed=true
  else
    print_error "Failed to add plymouth hook."
    return 1
  fi
else
  print_info "Plymouth hook already configured."
fi

# --- Update Kernel Parameters for a quiet boot experience ---

update_kernel_cmdline "${QUIET_FLAGS_HOOKS}" || {
  print_error "Failed to update kernel command line for Plymouth"
  return 1
}

# --- Regenerate Initramfs only if we changed the hooks ---
if [[ "$config_changed" == true ]]; then
  print_info "Configuration changed, regenerating initramfs..."
  regenerate_initramfs
else
  print_info "No changes to hooks, skipping initramfs regeneration."
fi

#===================================================================================
# GTK Theme
#===================================================================================
print_box "smslant" "GTK Theme"
print_step "Setting up GTK theme"
print_info "Setting GTK theme"

if [[ ! -d "${HOME}/.local/share/icons/Papirus-Dark" ]]; then
  print_info "Installing Papirus icon theme"
  if wget -qO- https://git.io/papirus-icon-theme-install | env DESTDIR="$HOME/.local/share/icons" sh >/dev/null 2>&1; then
    print_info "Papirus icon theme installed successfully"
  else
    print_warning "Failed to install Papirus icon theme"
  fi
else
  print_info "Papirus icon theme already exists"
fi

if gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" &&
  gsettings set org.gnome.desktop.interface font-name "SF Pro Text 12" &&
  gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" &&
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"; then
  print_info "GTK theme and icons set successfully"
else
  print_warning "Failed to set GTK theme or icons"
fi

# ===============================================================================
# MISCELLANEOUS
# ===============================================================================
print_box "smslant" "Miscellaneous"
print_step "Running miscellaneous setup tasks"

print_info "Updating pkgfile database"
if sudo pkgfile --update >/dev/null 2>&1; then
  print_info "pkgfile database updated successfully"
  enable_service "pkgfile-update.timer" "system"
else
  print_warning "Failed to update pkgfile database"
fi

# Regenerate fonts cache
print_info "Regenerating font cache"
if fc-cache -f -v >/dev/null 2>&1; then
  print_info "Font cache regenerated successfully"
else
  print_warning "Failed to regenerate font cache"
fi

if [[ ! -d "${HOME}/.local/share/gnupg" ]]; then
  print_info "Creating GnuPG directory"
  mkdir -p "${HOME}/.local/share/gnupg"
  chmod 700 "${HOME}/.local/share/gnupg"
  print_info "GnuPG directory created successfully"
else
  print_info "GnuPG directory already exists"
fi

if [[ ! -f "${HOME}/.config/wgetrc" ]]; then
  print_info "Creating wgetrc configuration file"
  mkdir -p "${HOME}/.config/wget"
  touch "${HOME}/.config/wget/wgetrc"
  print_info "wgetrc configuration file created successfully"
else
  print_info "wgetrc configuration file already exists"

fi

# ====================================================================================
# DNS OVER HTTPS
# ====================================================================================

if confirm "Do you want to enable DNS over HTTPS?"; then
  print_box "smslant" "DOH"
  print_step "Setting up DNS over HTTPS"

  readonly DNSCRYPT_CONFIG_FILE="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
  readonly NETWORKMANAGER_CONF="/etc/NetworkManager/conf.d/no-systemd-resolved.conf"

  install_package "dnscrypt-proxy"
  write_system_config "/etc/resolv.conf" "DNS over HTTPS configuration" <<EOF
# Generated by dnscrypt-proxy
# DO NOT EDIT THIS FILE MANUALLY
nameserver ::1
nameserver 127.0.0.1
options edns0
EOF

  declare -A cloudflare_dns=(
    ["server_names"]="['cloudflare', 'cloudflare-ipv6']"
  )
  for key in "${!cloudflare_dns[@]}"; do
    update_config "$DNSCRYPT_CONFIG_FILE" "$key" "${cloudflare_dns[$key]}"
  done

  enable_service "dnscrypt-proxy.service" "system"
  print_info "DNS over HTTPS enabled successfully"

  # Disable systemd-resolved if it's running
  if sudo systemctl is-active --quiet systemd-resolved; then
    print_info "Disabling systemd-resolved"
    if sudo systemctl disable --now systemd-resolved.service >/dev/null 2>&1; then
      print_info "systemd-resolved disabled successfully"
    else
      print_warning "Failed to disable systemd-resolved"
    fi
  fi

  if [[ ! -f "$NETWORKMANAGER_CONF" ]]; then
    write_system_config "$NETWORKMANAGER_CONF" "NetworkManager configuration to disable systemd-resolved" <<EOF
[main]
systemd-resolved=false
EOF
  fi

fi

# ===============================================================================
# FSTAB
# ===============================================================================

if is_btrfs; then
  if sudo sed -i -E '/btrfs/ { s/\brelatime\b/noatime/g; s/\bdefaults\b/defaults,noatime/g; s/(,noatime){2,}/,noatime/g; s/,+/,/g; }' /etc/fstab; then
    print_info "Updated /etc/fstab with noatime for Btrfs"
    reload_systemd_daemon
  else
    print_error "Failed to update /etc/fstab with noatime for Btrfs"
  fi

fi

# ===============================================================================
# FINALIZE
# ===============================================================================

if confirm "Setup done. Do you want to reboot now?"; then
  print_info "Rebooting system to apply changes..."
  reboot
else
  print_warning "Setup done, but you need to reboot for changes to take effect."
fi
