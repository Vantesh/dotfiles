#!/bin/bash

# =============================================================================
# BOOTLOADER DETECTION AND MANAGEMENT
# =============================================================================

detect_limine_bootloader() {
  has_cmd limine || [[ -x /usr/bin/limine ]]
}

detect_bootloader() {
  if detect_limine_bootloader; then
    echo "limine"
  elif has_cmd grub-mkconfig && [[ -f /etc/default/grub ]]; then
    echo "grub"
  else
    echo "unknown"
  fi
}

# =============================================================================
# BOOTLOADER CONFIGURATION FUNCTIONS
# =============================================================================

update_grub_cmdline() {
  local params="$1"
  local grub_file="/etc/default/grub"

  printc -n cyan "Updating GRUB configuration... "
  local current_cmdline
  current_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')

  local updated_cmdline="$current_cmdline"
  for param in $params; do
    if [[ ! "$current_cmdline" =~ $param ]]; then
      updated_cmdline="$updated_cmdline $param"
    fi
  done

  updated_cmdline=$(echo "$updated_cmdline" | sed 's/[ ]\+/ /g' | sed 's/^ *//' | sed 's/ *$//')

  if sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_cmdline\"|" "$grub_file"; then
    if sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
      printc green "OK"
    else
      fail "FAILED to generate GRUB config"
    fi
  else
    fail "FAILED to update GRUB defaults"
  fi
}

update_limine_cmdline() {
  local params="$1"
  local cmdline_file="/etc/kernel/cmdline"

  printc -n cyan "Updating Limine kernel cmdline... "
  local base_params
  base_params=$(cat "$cmdline_file" 2>/dev/null || echo "")

  for param in $params; do
    local param_name="${param%%=*}"
    base_params=$(echo "$base_params" |
      sed -E "s/(^| )${param_name}=[^ ]*//g; s/(^| )${param_name}( |$)//g")
  done

  # Compose the new cmdline: base params + hibernation params
  local combined_params="$base_params $params"
  # Remove duplicate parameters and clean up whitespace
  combined_params=$(echo "$combined_params" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/[ ]\+/ /g' | sed 's/^ *//' | sed 's/ *$//')

  if echo "$combined_params" | sudo tee "$cmdline_file" >/dev/null; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

update_kernel_cmdline() {
  local params="$1"
  local bootloader
  bootloader=$(detect_bootloader)

  case "$bootloader" in
  "limine")
    update_limine_cmdline "$params"
    ;;
  "grub")
    update_grub_cmdline "$params"
    ;;
  *)
    printc yellow "Unknown bootloader, skipping kernel parameter update"
    ;;
  esac
}

# =============================================================================
# LIMINE THEMING
# =============================================================================

configure_limine_interface() {
  printc cyan "Configuring Limine interface..."

  local limine_conf="/boot/limine.conf"

  if [[ ! -f "$limine_conf" ]]; then
    printc red "Limine config file not found at $limine_conf"
    return 1
  fi

  printc -n cyan "Setting interface options... "

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
      printc red "FAILED"
      return 1
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
  local git_url="https://github.com/semimqmo/sekiro_grub_theme"
  temp_folder=$(mktemp -d)
  printc -n cyan "Cloning GRUB theme... "
  if git clone "$git_url" "$temp_folder" >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED to clone GRUB theme repository"

  fi
  printc -n cyan "Installing GRUB theme... "
  if cd "$temp_folder" && sudo ./install.sh >/dev/null 2>&1; then
    printc green "OK"
  else
    fail "FAILED to install GRUB theme"
  fi

}

edit_grub_config() {
  local grub_file="/etc/default/grub"
  declare -A grub_config=(
    ["GRUB_TIMEOUT"]="2"
    ["GRUB_DEFAULT"]="0"
  )
  success=true
  printc -n cyan "Editing GRUB configuration... "
  for key in "${!grub_config[@]}"; do
    if ! update_config "$grub_file" "$key" "${grub_config[$key]}"; then
      success=false
      break
    fi
  done
  if [[ "$success" == true ]]; then
    printc green "OK"
  else
    fail "FAILED"
  fi

}
