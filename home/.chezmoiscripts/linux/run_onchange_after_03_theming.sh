#!/usr/bin/env bash
# 03_theming.sh - Configure system theming (bootloader, GTK, Qt)
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly GRUB_THEME_URL="https://github.com/semimqmo/sekiro_grub_theme"
readonly GRUB_THEME_DIR="/usr/share/grub/themes/Sekiro"
readonly TELA_REPO_URL="https://github.com/vinceliuice/Tela-icon-theme.git"
readonly TELA_ICON_DIR="$HOME/.local/share/icons/Tela"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

tela_icons_present() {
  LAST_ERROR=""

  if [[ -d "$TELA_ICON_DIR" ]]; then
    return 0
  fi

  local system_tela_dir="/usr/share/icons/Tela"

  if [[ -d "$system_tela_dir" ]]; then
    return 0
  fi

  return 1
}

install_grub_theme() {
  local temp_dir

  LAST_ERROR=""

  if [[ -d "$GRUB_THEME_DIR" ]]; then
    return 0
  fi

  temp_dir=$(mktemp -d)
  trap '[[ -d "${temp_dir:-}" ]] && rm -rf "${temp_dir}"' RETURN EXIT ERR

  if ! git clone "$GRUB_THEME_URL" "$temp_dir" >/dev/null 2>&1; then
    LAST_ERROR="Failed to clone GRUB theme repository"
    return 1
  fi

  if ! (cd "$temp_dir" && sudo ./install.sh >/dev/null 2>&1); then
    LAST_ERROR="Failed to install GRUB theme"
    return 1
  fi

  return 0
}

configure_limine_theme() {
  local limine_conf="/boot/limine.conf"
  local temp_file

  LAST_ERROR=""

  if [[ ! -f "$limine_conf" ]]; then
    LAST_ERROR="Limine config not found: $limine_conf"
    return 1
  fi

  if grep -q "Catppuccin Mocha Theme" "$limine_conf" 2>/dev/null; then
    return 0
  fi

  if ! create_backup "$limine_conf"; then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to backup limine config: $error_msg"
    return 1
  fi

  temp_file=$(mktemp)
  trap '[[ -f "${temp_file:-}" ]] && rm -f "${temp_file}"' RETURN

  cat <<'EOF' >"$temp_file"
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

  grep -vE "^[[:space:]]*#?[[:space:]]*(timeout|default_entry|interface_branding|term_palette|term_background|term_foreground):" "$limine_conf" 2>/dev/null >>"$temp_file" || true

  if ! sudo mv "$temp_file" "$limine_conf" 2>/dev/null; then
    local error_msg="Failed to write limine theme config"
    if ! restore_backup "$limine_conf"; then
      LAST_ERROR="$error_msg and restore backup failed: $LAST_ERROR"
    else
      LAST_ERROR="$error_msg (backup restored)"
    fi
    return 1
  fi

  return 0
}

configure_gtk_theme() {
  LAST_ERROR=""

  if ! gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set GTK theme"
    return 1
  fi

  if ! gsettings set org.gnome.desktop.interface font-name "SF Pro Text 12" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set font"
    return 1
  fi

  if ! gsettings set org.gnome.desktop.wm.preferences button-layout ":" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set button layout"
    return 1
  fi

  if ! gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set color scheme"
    return 1
  fi

  return 0
}

configure_nautilus() {
  LAST_ERROR=""

  if ! gsettings set org.gnome.nautilus.icon-view default-zoom-level "small-plus" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set Nautilus zoom level"
    return 1
  fi

  if ! gsettings set org.gnome.nautilus.preferences show-delete-permanently true >/dev/null 2>&1; then
    LAST_ERROR="Failed to set Nautilus delete permanently option"
    return 1
  fi

  return 0
}

add_nautilus_bookmarks() {
  local bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
  local bookmark

  LAST_ERROR=""

  if ! mkdir -p "$(dirname "$bookmarks_file")" 2>/dev/null; then
    LAST_ERROR="Failed to create bookmarks directory"
    return 1
  fi

  if [[ ! -f "$bookmarks_file" ]]; then
    if ! touch "$bookmarks_file" 2>/dev/null; then
      LAST_ERROR="Failed to create bookmarks file"
      return 1
    fi
  fi

  local folders=("Downloads" "Pictures" "Videos")
  local folder

  for folder in "${folders[@]}"; do
    bookmark="file://$HOME/$folder"

    if ! grep -Fxq "$bookmark" "$bookmarks_file" 2>/dev/null; then
      if ! printf '%s\n' "$bookmark" >>"$bookmarks_file" 2>/dev/null; then
        LAST_ERROR="Failed to add bookmark: $bookmark"
        return 1
      fi
    fi
  done

  return 0
}

install_tela_icons() {
  LAST_ERROR=""

  if tela_icons_present; then
    return 0
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  trap '[[ -d "${temp_dir:-}" ]] && rm -rf "${temp_dir}"' RETURN EXIT ERR

  if [[ ! -d "$temp_dir" ]]; then
    LAST_ERROR="Failed to create temporary directory"
    return 1
  fi

  if ! command_exists git; then
    LAST_ERROR="git is required to install Tela icons"
    return 1
  fi

  if ! git clone --depth 1 "$TELA_REPO_URL" "$temp_dir" >/dev/null 2>&1; then
    LAST_ERROR="Failed to clone Tela icon theme repository"
    return 1
  fi

  if ! (cd "$temp_dir" && ./install.sh -a >/dev/null 2>&1); then
    LAST_ERROR="Failed to install Tela icons"
    return 1
  fi

  return 0
}

configure_qt_theme() {
  local version="$1"
  local config_dir="$HOME/.config/$version"
  local config_file="$config_dir/${version}.conf"

  LAST_ERROR=""

  if [[ -z "$version" ]]; then
    LAST_ERROR="configure_qt_theme() requires version argument"
    return 2
  fi

  if [[ -f "$config_file" ]]; then
    return 0
  fi

  if ! mkdir -p "$config_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create Qt config directory: $config_dir"
    return 1
  fi

  if ! cat <<EOF >"$config_file" 2>/dev/null; then
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
    LAST_ERROR="Failed to write Qt config: $config_file"
    return 1
  fi

  return 0
}

main() {
  local bootloader

  print_box "Theming"
  log STEP "System Theming"

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  case "$bootloader" in
  grub)
    if ! install_grub_theme; then
      if [[ -d "$GRUB_THEME_DIR" ]]; then
        log SKIP "GRUB theme already installed"
      else
        log WARN "Failed to install GRUB theme: $LAST_ERROR"
      fi
    else
      log INFO "Installed GRUB theme"
    fi
    ;;
  limine)

    if [[ "${DISTRO,,}" = "cachyos" ]]; then
      log SKIP "CachyOS has pre-configured Limine theme"
    else
      if ! configure_limine_theme; then
        if grep -q "Catppuccin Mocha Theme" /boot/limine.conf 2>/dev/null; then
          log SKIP "Limine theme already configured"
        else
          log WARN "Failed to configure Limine theme: $LAST_ERROR"
        fi
      else
        log INFO "Configured Limine theme"
      fi
    fi
    ;;
  *)
    log SKIP "No theme available for bootloader: $bootloader"
    ;;
  esac

  if command_exists gsettings; then
    if ! configure_gtk_theme; then
      log WARN "Failed to configure GTK theme: $LAST_ERROR"
    else
      log INFO "Configured GTK theme"
    fi
  else
    log SKIP "gsettings not available, skipping GTK theme"
  fi

  if command_exists gsettings; then
    if ! configure_nautilus; then
      log WARN "Failed to configure Nautilus: $LAST_ERROR"
    else
      log INFO "Configured Nautilus preferences"
    fi

    if ! add_nautilus_bookmarks; then
      log WARN "Failed to add Nautilus bookmarks: $LAST_ERROR"
    else
      log INFO "Added Nautilus bookmarks"
    fi
  else
    log SKIP "gsettings not available, skipping Nautilus configuration"
  fi

  local qt_version
  for qt_version in qt5ct qt6ct; do
    if ! configure_qt_theme "$qt_version"; then
      if [[ -f "$HOME/.config/$qt_version/${qt_version}.conf" ]]; then
        log SKIP "$qt_version already configured"
      else
        log WARN "Failed to configure $qt_version: $LAST_ERROR"
      fi
    else
      log INFO "Configured $qt_version theme"
    fi
  done

  case "${DISTRO_FAMILY,,}" in
  *fedora*)
    if tela_icons_present; then
      log SKIP "Tela icons already installed"
    else
      log INFO "Installing Tela icons (this may take a moment)"

      if ! install_tela_icons; then
        local error_msg="$LAST_ERROR"
        log WARN "Failed to install Tela icons: $error_msg"
      else
        log INFO "Installed Tela icon theme"
      fi
    fi
    ;;
  esac

  log INFO "System theming complete"
}

main "$@"
