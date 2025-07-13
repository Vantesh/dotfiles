#!/bin/bash

# shellcheck disable=SC1091

# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/dotfiles/.chezmoiscripts/.00_helpers.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

DEPS=(
  adw-gtk-theme
)
readonly FONTS_REPO_URL="https://github.com/Vantesh/Fonts.git"
readonly FONTS_TARGET_DIR="$HOME/.local/share/fonts"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done
}

install_papirus_folders() {
  if [[ ! -d "$HOME/.local/share/icons/Papirus-Dark" ]]; then
    if wget -qO- https://git.io/papirus-icon-theme-install | env DESTDIR="$HOME/.local/share/icons" sh; then
      printc green "Papirus icon theme installed successfully."
    else
      fail "Failed to install Papirus icon theme."
    fi
  else
    printc green "Papirus icon theme already installed."
  fi

}

# =============================================================================
# FONT INSTALLATION FUNCTIONS
# =============================================================================

check_existing_fonts() {
  if compgen -G "$FONTS_TARGET_DIR/*.ttf" >/dev/null || compgen -G "$FONTS_TARGET_DIR/*.otf" >/dev/null; then
    printc green "Fonts already installed"
    return 0
  fi
  return 1
}

clone_fonts_repository() {
  local temp_dir="$1"
  printc -n cyan "Cloning fonts... "
  if git clone --depth=1 "$FONTS_REPO_URL" "$temp_dir" 2>/dev/null; then
    printc green "OK"
  else
    rm -rf "$temp_dir"
    fail "FAILED"
  fi
}

copy_font_files() {
  local temp_dir="$1"
  local new_count=0
  local update_count=0

  printc -n cyan "Installing fonts... "

  mapfile -t font_files < <(find "$temp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \))

  if [[ ${#font_files[@]} -eq 0 ]]; then
    rm -rf "$temp_dir"
    fail "No fonts found"
  fi

  for font_file in "${font_files[@]}"; do
    local font_name
    font_name=$(basename "$font_file")
    local target_font="$FONTS_TARGET_DIR/$font_name"

    if [[ -f "$target_font" ]]; then
      if ! cmp -s "$font_file" "$target_font"; then
        cp "$font_file" "$target_font"
        ((update_count++))
      fi
    else
      cp "$font_file" "$target_font"
      ((new_count++))
    fi
  done

  if ((new_count > 0 || update_count > 0)); then
    fc-cache -f "$FONTS_TARGET_DIR" 2>/dev/null
    printc green "OK ($new_count new, $update_count updated)"
  else
    printc green "up to date"
  fi
}

install_fonts() {
  mkdir -p "$FONTS_TARGET_DIR"

  if check_existing_fonts; then
    return 0
  fi

  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temp directory"

  if clone_fonts_repository "$temp_dir"; then
    pushd "$temp_dir" &>/dev/null || return
    copy_font_files "$temp_dir"
    popd &>/dev/null || return
    rm -rf "$temp_dir"
  else
    rm -rf "$temp_dir"
    fail "FAILED to clone fonts repository"
  fi
}

# =============================================================================
# SDDM CONFIGURATION
# =============================================================================

configure_sddm() {
  printc -n cyan "Configuring SDDM... "

  if ! write_system_config "/etc/sddm.conf.d/10-wayland.conf" "SDDM Wayland configuration" <<'EOF' >/dev/null 2>&1; then
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF
    fail "FAILED to write Wayland configuration"
  fi

  if ! write_system_config "/etc/sddm.conf.d/hidpi.conf" "SDDM HIDPI configuration" <<'EOF' >/dev/null 2>&1; then
[Wayland]
EnableHiDPI=true
EOF
    fail "FAILED to write HiDPI configuration"
  fi

  if ! sudo cp -r "${CHEZMOI_WORKING_TREE}/sddm/stray" /usr/share/sddm/themes/ && sudo chmod -R 755 /usr/share/sddm/themes/stray; then
    fail "FAILED to copy SDDM stray theme files"
  fi

  if ! write_system_config "/etc/sddm.conf.d/theme.conf" "SDDM theme" <<'EOF' >/dev/null 2>&1; then
[Theme]
Current=stray
EOF
    fail "FAILED to write SDDM theme configuration"
  fi
  printc green "OK"
}

# =============================================================================
# LIMINE THEMING
# =============================================================================

configure_limine_interface() {
  printc -n cyan "Configuring Limine interface..."

  local limine_conf="/boot/limine.conf"

  if [[ ! -f "$limine_conf" ]]; then
    printc red "Limine config file not found at $limine_conf"
    return 1
  fi

  # Interface configuration parameters
  local PARAMS=(
    "term_palette: 1e1e2e;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_palette_bright: 585b70;f38ba8;a6e3a1;f9e2af;89b4fa;f5c2e7;94e2d5;cdd6f4"
    "term_background: 1e1e2e"
    "term_foreground: cdd6f4"
    "term_background_bright: 1e1e2e"
    "term_foreground_bright: cdd6f4"
    "timeout: 1"
    "default_entry: 2"
    "interface_branding: Arch Linux"
  )

  # Build interface configuration block
  local interface_config=$'\n# Interface Configuration\n'
  for param in "${PARAMS[@]}"; do
    interface_config+="$param"$'\n'
  done

  # Find the line with "/+Arch Linux" and insert interface config above it
  if grep -q "/+Arch Linux" "$limine_conf"; then
    # Create a temporary file with the interface config inserted
    if awk -v config="$interface_config" '
      /\/\+Arch Linux/ {
        print config
        print $0
        next
      }
      # Skip existing interface config lines if they exist
      /^term_palette:|^term_palette_bright:|^term_background:|^term_foreground:|^term_background_bright:|^term_foreground_bright:|^timeout:|^wallpaper:|^interface_branding:|^default_entry:/ {
        next
      }
      { print }
    ' "$limine_conf" | sudo tee "${limine_conf}.tmp" >/dev/null && sudo mv "${limine_conf}.tmp" "$limine_conf"; then
      printc green "OK"
    else
      fail "FAILED to update Limine config"
    fi
  else
    printc yellow "Arch Linux entry not found in $limine_conf"
    return 1
  fi
}

# =============================================================================
# GRUB THEMING
# =============================================================================

install_grub_theme() {
  # Check if GRUB theme already exists
  if [[ -d "/usr/share/grub/themes/Sekiro" ]]; then
    printc green "GRUB theme already installed"
    return
  fi

  local git_url="https://github.com/semimqmo/sekiro_grub_theme"
  temp_folder=$(mktemp -d)
  printc -n cyan "Cloning GRUB theme... "
  if git clone "$git_url" "$temp_folder" >/dev/null 2>&1; then
    printc green "OK"
  else
    rm -rf "$temp_folder"
    fail "FAILED to clone GRUB theme repository"
  fi
  printc -n cyan "Installing GRUB theme... "
  pushd "$temp_folder" &>/dev/null || return
  if sudo ./install.sh >/dev/null 2>&1; then
    printc green "OK"
  else
    popd &>/dev/null || return
    rm -rf "$temp_folder"
    fail "FAILED to install GRUB theme"
  fi
  popd &>/dev/null || return
  rm -rf "$temp_folder"
}

# =============================================================================
# PLYMOUTH CONFIGURATION FUNCTIONS
# =============================================================================

setup_plymouth() {
  printc cyan "Setting up Plymouth..."

  install_package "plymouth"

  printc -n cyan "Configuring Plymouth hooks... "
  local mkinitcpio_conf="/etc/mkinitcpio.conf"
  if ! grep -q "plymouth" "$mkinitcpio_conf"; then
    if sudo sed -i '/^HOOKS=/ s/\(.*\) filesystems\(.*\)/\1 plymouth filesystems\2/' "$mkinitcpio_conf"; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  else
    printc yellow "already configured"
  fi

  local quiet_flags="quiet loglevel=3 splash vt.global_cursor_default=0 nowatchdog rd.udev.log_level=3"
  update_kernel_cmdline "$quiet_flags"
  regenerate_initramfs
}

# =============================================================================
# GTK THEMING
# =============================================================================
configure_gtk_theme() {
  printc -n cyan "Configuring GTK theme... "
  if gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" &&
    gsettings set org.gnome.desktop.interface font-name "SF Pro Text 12" &&
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" &&
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"; then
    printc green "OK"
  else
    printc red "FAILED"
    return 1
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

printc_box "THEMING" "Setting up Fonts, cursors and themes"

install_dependencies
install_papirus_folders
install_fonts
configure_sddm
configure_gtk_theme

if [[ "$(detect_bootloader)" == "limine" ]]; then
  if grep -q "CachyOS" /etc/os-release; then
    printc yellow "Skipping Limine theming on CachyOS"
  else
    configure_limine_interface
  fi
elif [[ "$(detect_bootloader)" == "grub" ]]; then
  install_grub_theme
  edit_grub_config
else
  printc yellow "No supported bootloader detected, skipping theming setup"
fi

if echo && confirm "Install and configure Plymouth for boot splash?"; then
  setup_plymouth
else
  printc yellow "Skipping Plymouth setup."
fi
