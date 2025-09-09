#!/usr/bin/env bash

# shellcheck disable=SC1091
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.00_helpers"
source "${CHEZMOI_SOURCE_DIR:?env variable missing. Please only run this script via chezmoi}/.chezmoiscripts/linux/helpers/.02_XDG"

# =============================================================================
# Initialize Environment
# =============================================================================
common_init

# =============================================================================
# SNAPPER
# =============================================================================
if is_btrfs && confirm "Set up Snapper?"; then
  print_box "smslant" "Snapper"
  print_step "Setting up Snapper configuration"
  snapper_deps=(
    snapper
    snap-pac
    btrfs-assistant
    btrfs-progs
    inotify-tools
  )
  snapper_services=(
    snapper-cleanup.timer
  )

  if [[ "$(detect_bootloader)" == "limine" ]]; then
    snapper_deps+=(
      limine-mkinitcpio-hook
      limine-snapper-sync
    )
    snapper_services+=(
      limine-snapper-sync.service
    )

  elif [[ "$(detect_bootloader)" == "grub" ]]; then
    snapper_deps+=(
      grub-btrfs
    )
    snapper_services+=(
      grub-btrfsd.service
    )
  fi

  install_package "${snapper_deps[@]}"

  for service in "${snapper_services[@]}"; do
    enable_service "$service" "system"
  done

  # limine configuration
  if [[ "$(detect_bootloader)" == "limine" ]]; then
    readonly LIMINE_CONFIG_FILE="/etc/default/limine"
    readonly LIMINE_ENTRY_TEMPLATE="/etc/limine-entry-tool.conf"
    readonly LIMINE_SNAPPER_TEMPLATE="/etc/limine-snapper-sync.conf"

    if [[ ! -f "$LIMINE_ENTRY_TEMPLATE" || ! -f "$LIMINE_SNAPPER_TEMPLATE" ]]; then
      print_error "Limine templates not found."
    fi

    if {
      cat "$LIMINE_ENTRY_TEMPLATE"
      echo
      echo # just to space out the entry
      cat "$LIMINE_SNAPPER_TEMPLATE"
    } | sudo tee "$LIMINE_CONFIG_FILE" >/dev/null; then
      print_info "Limine snapper template added."
    else
      print_error "Failed to update Limine configuration."
    fi
    declare -A limine_entries=(
      ["MAX_SNAPSHOT_ENTRIES"]=15
      ["TERMINAL"]="kitty"
      ["TERMINAL_ARG"]="-e"
      ["SNAPSHOT_FORMAT_CHOICE"]=0
      ["QUIET_MODE"]="yes"
      ["ENABLE_LIMINE_FALLBACK"]="yes"
    )

    if [[ -f /etc/kernel/cmdline ]]; then
      limine_entries["ENABLE_UKI"]="yes"
    fi

    success=true
    for key in "${!limine_entries[@]}"; do
      if ! update_config "$LIMINE_CONFIG_FILE" "$key" "${limine_entries[$key]}"; then
        print_error "Failed to update $key in $LIMINE_CONFIG_FILE"
        success=false
        break
      fi
    done

    if $success; then
      print_info "Limine configuration updated successfully."
    else
      print_error "Failed to update Limine configuration."
    fi
  fi

  # Snapper configuration
  declare -A snapper_settings=(
    ["NUMBER_CLEANUP"]="yes"
    ["NUMBER_LIMIT"]="20"
    ["TIMELINE_CREATE"]="no"
    ["TIMELINE_CLEANUP"]="yes"
    ["TIMELINE_MIN_AGE"]="1800"
    ["TIMELINE_LIMIT_HOURLY"]="5"
    ["TIMELINE_LIMIT_DAILY"]="7"
    ["TIMELINE_LIMIT_WEEKLY"]="0"
    ["TIMELINE_LIMIT_MONTHLY"]="0"
    ["TIMELINE_LIMIT_YEARLY"]="0"
    ["EMPTY_PRE_POST_CLEANUP"]="yes"
    ["EMPTY_PRE_POST_MIN_AGE"]="1800"
  )

  success=true
  for key in "${!snapper_settings[@]}"; do
    if ! set_snapper_config_value "root" "$key" "${snapper_settings[$key]}"; then
      print_error "Failed to set Snapper config: $key"
      success=false
      break
    fi
  done

  if $success; then
    print_info "Snapper configuration updated successfully."
  else
    print_error "Failed to update Snapper configuration."
  fi

  case "$(detect_bootloader)" in
  grub) overlay_hook="grub-btrfs-overlayfs" ;;
  limine) overlay_hook="btrfs-overlayfs" ;;
  esac

  if [[ -n $overlay_hook ]]; then
    hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' /etc/mkinitcpio.conf | head -n1)
    if [[ -n $hooks && $hooks != *" systemd "* ]]; then
      new_hooks=$(sed -E "s/(^| )${overlay_hook//-/\\-}( |$)/ /g" <<<"$hooks" | xargs)
      new_hooks=$(xargs <<<"$new_hooks $overlay_hook")
      if [[ $new_hooks != "$hooks" ]]; then
        if sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" /etc/mkinitcpio.conf; then
          print_info "Updated mkinitcpio HOOKS (added $overlay_hook)"
          regenerate_initramfs
        else
          print_error "Failed to update mkinitcpio HOOKS"
        fi
      fi
    fi
  fi

fi
