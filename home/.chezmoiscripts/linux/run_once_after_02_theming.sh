#!/usr/bin/env bash
# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.02_XDG"

common_init

readonly GRUB_THEME_URL="https://github.com/semimqmo/sekiro_grub_theme"
readonly QUIET_FLAGS_HOOKS="quiet splash loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0"

# Track whether we changed system-level configuration that requires regenerating initramfs
config_changed=false
mkinitcpio_conf="/etc/mkinitcpio.conf"
limine_conf="/boot/limine.conf"

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

  THEME_BLOCK=$(
    cat <<'EOF'
# Catppuccin Mocha Theme
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

  if ! grep -q "Catppuccin Mocha Theme" "$limine_conf"; then
    if create_backup "$limine_conf"; then
      if printf "%s\n" "$THEME_BLOCK" | sudo tee "$limine_conf" >/dev/null; then
        print_info "Limine theme has been written to $limine_conf."
        config_changed=true
      else
        print_error "Failed to write $limine_conf."
      fi
    else
      print_error "Failed to create backup of $limine_conf. Aborting limine theme write."
    fi
  else
    print_warning "Limine theme already configured, skipping"
  fi
fi

#===================================================================================
# Plymouth
#===================================================================================
print_box "smslant" "Plymouth"
print_step "Setting up Plymouth"

print_info "Checking mkinitcpio hooks for plymouth..."

if ! sudo grep -qE '^\s*HOOKS=.*\bplymouth\b' "$mkinitcpio_conf"; then
  # Add plymouth to HOOKS array after 'base systemd' or 'base udev'
  if grep "^HOOKS=" "$mkinitcpio_conf" | grep -q "base systemd"; then
    if sudo sed -i '/^HOOKS=/s/base systemd/base systemd plymouth/' "$mkinitcpio_conf"; then
      config_changed=true
    else
      print_error "Failed to add plymouth after 'base systemd'."
    fi
  elif grep "^HOOKS=" "$mkinitcpio_conf" | grep -q "base udev"; then
    if sudo sed -i '/^HOOKS=/s/base udev/base udev plymouth/' "$mkinitcpio_conf"; then
      config_changed=true
    else
      print_error "Failed to add plymouth after 'base udev'."
    fi
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

if [ ! -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf ]; then
  # Make plymouth remain until graphical.target
  write_system_config "/etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf" "wait-for-graphical.conf" <<EOF
[Unit]
After=multi-user.target
EOF
fi

# Mask plymouth-quit-wait.service only if not already masked
if ! systemctl is-enabled plymouth-quit-wait.service | grep -q masked; then
  sudo systemctl mask plymouth-quit-wait.service
  reload_systemd_daemon
fi

# --- Regenerate Initramfs only if configuration changed ---
if [[ "$config_changed" == true ]]; then
  print_info "Configuration changed, regenerating initramfs..."
  regenerate_initramfs
else
  print_info "No changes to hooks, skipping initramfs regeneration."
fi

#===================================================================================
# GTK Theme
#===================================================================================
print_box "smslant" "GTK & QT"
print_step "Setting up GTK theme"

if gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" &&
  gsettings set org.gnome.desktop.interface font-name "SF Pro Text 12" &&
  gsettings set org.gnome.desktop.wm.preferences button-layout ':' &&
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"; then
  print_info "GTK theme and icons set successfully"
else
  print_warning "Failed to set GTK theme or icons"
fi

print_step "Setting up Nautilus"

if gsettings set org.gnome.nautilus.icon-view default-zoom-level 'small-plus' &&
  gsettings set org.gnome.nautilus.preferences show-delete-permanently true; then
  print_info "Nautilus preferences set successfully"
else
  print_warning "Failed to set Nautilus preferences"
fi

bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$bookmarks_file")" && touch "$bookmarks_file"

success=true
for folder in Downloads Pictures Videos; do
  bookmark="file://$HOME/$folder"
  if ! grep -Fxq "$bookmark" "$bookmarks_file"; then
    echo "$bookmark" >>"$bookmarks_file" || success=false
  fi
done

if $success; then
  print_info "Nautilus bookmarks set successfully"
else
  print_warning "Failed to set Nautilus bookmarks"
fi
# ==================================================================================
# QT THEME
# ==================================================================================
print_step "Setting up QT theme"

for version in qt5ct qt6ct; do
  config_dir="$HOME/.config/$version"
  config_file="$config_dir/${version}.conf"

  if [[ -f "$config_file" ]]; then
    print_warning "$version theme already configured, skipping"
  else
    mkdir -p "$config_dir"
    cat <<EOF >"$config_file"
[Appearance]
color_scheme_path=${HOME}/.local/share/color-schemes/Matugen.colors
custom_palette=true
icon_theme=
standard_dialogs=default
style=Darkly

[Fonts]
fixed="JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0,Regular"
general="SF Pro Text,12,-1,5,50,0,0,0,0,0,Regular"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
EOF
    print_info "$version config configured successfully"
  fi
done
