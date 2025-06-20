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

  read -ra param_array <<<"$params"
  local updated_cmdline="$current_cmdline"

  for param in "${param_array[@]}"; do
    # Extract parameter name (before = or the whole param if no =)
    local param_name
    if [[ "$param" == *"="* ]]; then
      param_name="${param%%=*}"
    else
      param_name="$param"
    fi
    # Remove existing instances of this parameter
    updated_cmdline=$(echo "$updated_cmdline" | sed -E "s/(^|[[:space:]])${param_name}(=[^[:space:]]*)?([[:space:]]|$)/ /g")
  done

  updated_cmdline="$updated_cmdline $params"

  # Clean up spacing and remove any remaining duplicates
  updated_cmdline=$(echo "$updated_cmdline" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

  if sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$updated_cmdline\"|" "$grub_file"; then
    # Small delay to ensure file is written to disk
    sleep 1
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

  read -ra param_array <<<"$params"
  for param in "${param_array[@]}"; do
    local param_name
    if [[ "$param" == *"="* ]]; then
      param_name="${param%%=*}"
    else
      param_name="$param"
    fi
    base_params=$(echo "$base_params" | sed -E "s/(^|[[:space:]])${param_name}(=[^[:space:]]*)?([[:space:]]|$)/ /g")
  done

  local combined_params="$base_params $params"

  # Remove duplicates and clean up spacing
  combined_params=$(echo "$combined_params" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

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
