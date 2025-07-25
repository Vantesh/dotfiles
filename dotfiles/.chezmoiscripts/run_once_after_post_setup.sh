#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/helpers/.00_helpers"

readonly GRUB_THEME_URL="https://github.com/semimqmo/sekiro_grub_theme"
readonly QUIET_FLAGS_HOOKS="quiet loglevel=3 splash vt.global_cursor_default=0 nowatchdog rd.udev.log_level=3"
readonly ZSHENV_FILE="/etc/zsh/zshenv"

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
if sudo cp -r "${CHEZMOI_WORKING_TREE}/extras/sddm/stray" /usr/share/sddm/themes/; then
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

if [[ $(detect_bootloader) == "grub" ]]; then
  print_box "smslant" "GRUB"
  print_step "Setting up GRUB theme"
  temp_dir=$(mktemp -d)
  if [[ ! -d "/usr/share/grub/themes/Sekiro" ]]; then
    print_info "Installing GRUB theme"
    if git clone "${GRUB_THEME_URL}" "$temp_dir" >/dev/null 2>&1; then
      if cd "$temp_dir" && sudo ./install.sh >/dev/null 2>&1; then
        print_info "GRUB theme installed successfully"
        cd - >/dev/null || true
        rm -rf "$temp_dir"
      fi
    fi
  else
    print_warning "GRUB theme already exists"
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

# ==================================================================================
# ZSH
# ==================================================================================
print_box "smslant" "ZSH"
print_step "Setting up ZSH"
write_system_config "$ZSHENV_FILE" "ZSH environment configuration" <<EOF
# ZSH environment configuration


# ZSH environment file

# This file is sourced by ZSH at startup to set environment variables.
# XDG BASE DIRS

# export XDG Base Directories
if [[ -z "$XDG_CONFIG_HOME" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi

if [[ -z "$XDG_CACHE_HOME" ]]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi

if [[ -z "$XDG_STATE_HOME" ]]; then
  export XDG_STATE_HOME="$HOME/.local/state"
fi

# export ZDOTDIR
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
EOF

# zsh_pacman_hook
write_system_config "/etc/pacman.d/hooks/zsh.hook" "ZSH Pacman Hook" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Path
Target = usr/bin/*

[Action]
Depends = zsh
Depends = procps-ng
Description = Reloading zsh shell...
When = PostTransaction
Exec = /usr/bin/pkill zsh --signal=USR1
EOF

# make zsh the default shell
if confirm "Do you want to set ZSH as your default shell?"; then
  if chsh -s "$(which zsh)" >/dev/null 2>&1; then
    print_info "ZSH set as default shell successfully"
  else
    print_error "Failed to set ZSH as default shell"
  fi
else
  print_info "Skipping setting ZSH as default shell"
fi

if confirm "Make ZSH default for root user?"; then
  if sudo chsh -s "$(which zsh)" root >/dev/null 2>&1; then
    if [[ ! -d "/root/.config" ]]; then
      sudo mkdir -p "/root/.config"
      if sudo cp -r "${HOME}/.config/zsh" "/root/.config/" &&
        sudo cp -r "${HOME}/.config/ohmyposh" "/root/.config/" &&
        sudo cp -r "${HOME}/.config/fsh" "/root/.config/"; then
        print_info "ZSH configuration copied for root user"
      else
        print_error "Failed to copy ZSH configuration for root user"
      fi
    fi
  fi

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
    update_config_file "$DNSCRYPT_CONFIG_FILE" "$key" "${cloudflare_dns[$key]}"
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
