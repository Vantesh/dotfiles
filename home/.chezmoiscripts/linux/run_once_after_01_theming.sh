#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"

common_init

readonly GRUB_THEME_URL="https://github.com/semimqmo/sekiro_grub_theme"
readonly QUIET_FLAGS_HOOKS="quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog"

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
  fi
else
  print_info "Plymouth hook already configured."
fi

# --- Update Kernel Parameters for a quiet boot experience ---
case "$(detect_bootloader)" in
  grub)
    update_grub_cmdline "${QUIET_FLAGS_HOOKS}" || {
      print_error "Failed to update GRUB kernel command line for Plymouth"
    }
    ;;
  limine)
    # Ensure the Limine default drop-in exists once, sourced from /proc/cmdline
    if [[ ! -f /etc/limine-entry-tool.d/01-default.conf ]]; then
      if [[ -r /proc/cmdline ]]; then
        update_limine_cmdline "01-default.conf" "$(cat /proc/cmdline)"
      else
        print_error "/proc/cmdline not readable; cannot create default Limine drop-in"
      fi
    fi
    # Add quiet flags into a dedicated drop-in
    update_limine_cmdline "20-quiet-boot.conf" "${QUIET_FLAGS_HOOKS}" || {
      print_error "Failed to write Limine drop-in for Plymouth"
    }
    ;;
  *)
    print_warning "Unsupported bootloader, skipping kernel parameter update."
    ;;
esac

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
