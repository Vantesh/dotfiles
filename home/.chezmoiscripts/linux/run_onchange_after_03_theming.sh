#!/usr/bin/env bash
# 03_theming.sh - Configure system theming (bootloader, GTK)
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
readonly -a LIMINE_OPTIONS=(
  "timeout=0.5"
  "terse=yes"
  "quiet=yes"
  "firmware_logo=yes"
  "interface_help_hidden=yes"
  "mouse=no"

)

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

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

configure_limine_options() {
  local limine_conf="/boot/limine.conf"
  local temp_file
  local limine_options

  LAST_ERROR=""

  if ! command_exists limine-entry-tool; then
    LAST_ERROR="limine-entry-tool is not installed"
    return 2
  fi

  if ! sudo test -f "$limine_conf"; then
    LAST_ERROR="Limine config not found: $limine_conf"
    return 2
  fi

  if ! create_backup "$limine_conf"; then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to backup limine config: $error_msg"
    return 1
  fi

  temp_file=$(mktemp)
  trap '[[ -f "${temp_file:-}" ]] && rm -f "${temp_file}"' RETURN

  limine_options="$(printf '%s\n' "${LIMINE_OPTIONS[@]}")"

  if ! sudo awk -v "limine_options=$limine_options" '
    function emit_missing_options( option_index, option_parts, option_name) {
      for (option_index = 1; option_index <= limine_option_count; option_index++) {
        split(limine_option[option_index], option_parts, "=")
        option_name = option_parts[1]
        if (!(option_name in emitted_options)) {
          print option_name ": " desired_values[option_name]
          emitted_options[option_name] = 1
        }
      }
    }

    function emit_entry_spacing() {
      print ""
      print ""
      print ""
    }

    BEGIN {
      entry_seen = 0
      trim_entry_padding = 0
      limine_option_count = split(limine_options, limine_option, "\n")
      if (limine_option[limine_option_count] == "") {
        limine_option_count--
      }

      for (option_index = 1; option_index <= limine_option_count; option_index++) {
        split(limine_option[option_index], option_parts, "=")
        desired_options[option_parts[1]] = 1
        desired_values[option_parts[1]] = substr(limine_option[option_index], length(option_parts[1]) + 2)
      }
    }

    {
      if (trim_entry_padding && $0 ~ /^[[:space:]]*$/) {
        next
      }
      trim_entry_padding = 0

      if (!entry_seen && $0 ~ /^[[:space:]]*$/) {
        pending_blank_lines++
        next
      }

      if (!entry_seen && $0 ~ /^\//) {
        emit_missing_options()
        emit_entry_spacing()
        pending_blank_lines = 0
        entry_seen = 1
        trim_entry_padding = 1
        print
        next
      }

      if (pending_blank_lines > 0) {
        for (blank_index = 0; blank_index < pending_blank_lines; blank_index++) {
          print ""
        }
        pending_blank_lines = 0
      }

      normalized_line = $0
      sub(/^[[:space:]]*#?[[:space:]]*/, "", normalized_line)
      split(normalized_line, fields, ":")
      option_name = fields[1]
      sub(/[[:space:]]+$/, "", option_name)

      if (option_name in desired_options) {
        if (entry_seen || (option_name in emitted_options)) {
          next
        }

        print option_name ": " desired_values[option_name]
        emitted_options[option_name] = 1
        next
      }

      print
    }

    END {
      emit_missing_options()
    }
  ' "$limine_conf" >"$temp_file"; then
    LAST_ERROR="Failed to transform Limine config"
    return 1
  fi

  if ! sudo mv "$temp_file" "$limine_conf" 2>/dev/null; then
    local error_msg="Failed to write Limine options"
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
    local limine_result=0
    configure_limine_options || limine_result=$?
    if [[ "$limine_result" -eq 2 ]]; then
      log SKIP "Limine configuration skipped: $LAST_ERROR"
    elif [[ "$limine_result" -ne 0 ]]; then
      log WARN "Failed to configure Limine options: $LAST_ERROR"
    else
      log INFO "Configured Limine options"
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

  log INFO "System theming complete"
}

main "$@"
