#!/usr/bin/env bash
# .lib-snapboot.sh - Bootloader and filesystem configuration management
#
# Provides unified interface for bootloader configuration (GRUB, Limine),
# initramfs generation (mkinitcpio, dracut), and filesystem operations (btrfs, fstab).
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args/already exists), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

# Merges kernel command line parameters.
#
# Combines current and new parameters, with new params overriding duplicates.
# Maintains parameter order. Intentionally uses word splitting on parameters.
#
# Arguments:
#   $1 - Current kernel command line (space-separated)
#   $2 - New parameters to add/override (space-separated)
# Globals:
#   LAST_ERROR - Set on invalid args
# Outputs:
#   Merged command line to stdout
# Returns:
#   0 on success, 2 on missing arguments
build_cmdline() {
  local current="${1:-}"
  local new_params="${2:-}"

  LAST_ERROR=""

  if [[ -z "$current" ]] && [[ -z "$new_params" ]]; then
    LAST_ERROR="build_cmdline() requires at least one argument"
    return 2
  fi

  declare -A params_map
  local -a ordered_keys=()
  local param key

  # Parse current parameters - intentional word splitting
  if [[ -n "$current" ]]; then
    # shellcheck disable=SC2086
    while IFS= read -r param; do
      [[ -z "$param" ]] && continue
      key="${param%%=*}"
      if [[ -z "${params_map[$key]+x}" ]]; then
        ordered_keys+=("$key")
      fi
      params_map["$key"]="$param"
    done < <(printf '%s\n' $current)
  fi

  # Parse new parameters - intentional word splitting (override existing)
  if [[ -n "$new_params" ]]; then
    # shellcheck disable=SC2086
    while IFS= read -r param; do
      [[ -z "$param" ]] && continue
      key="${param%%=*}"
      if [[ -z "${params_map[$key]+x}" ]]; then
        ordered_keys+=("$key")
      fi
      params_map["$key"]="$param"
    done < <(printf '%s\n' $new_params)
  fi

  # Build result array
  local -a result=()
  for key in "${ordered_keys[@]}"; do
    result+=("${params_map[$key]}")
  done

  printf '%s\n' "${result[*]}"
  return 0
}

# Verifies root filesystem is btrfs.
#
# Uses findmnt to check if root (/) is mounted on btrfs.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 if root is btrfs, 1 if not, 127 if findmnt missing
check_btrfs() {
  LAST_ERROR=""

  if ! command_exists findmnt; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  if ! findmnt -n -o FSTYPE / 2>/dev/null | grep -q "^btrfs$"; then
    LAST_ERROR="Root filesystem is not btrfs"
    return 1
  fi

  return 0
}

# Adds hook to mkinitcpio.conf HOOKS array.
#
# skips if hook already present. Preserves existing hooks order.
#
# Arguments:
#   $1 - Hook name to add
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success (added or already present), 1 on failure, 2 on invalid args
add_mkinitcpio_hook() {
  local hook="${1:-}"
  local mkinitcpio_conf="/etc/mkinitcpio.conf"

  LAST_ERROR=""

  if [[ -z "$hook" ]]; then
    LAST_ERROR="add_mkinitcpio_hook() requires hook name"
    return 2
  fi

  if [[ ! -f "$mkinitcpio_conf" ]]; then
    LAST_ERROR="mkinitcpio.conf not found"
    return 1
  fi

  local current_hooks
  current_hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

  if [[ -z "$current_hooks" ]]; then
    LAST_ERROR="Failed to parse HOOKS from mkinitcpio.conf"
    return 1
  fi

  if [[ " $current_hooks " = *" $hook "* ]]; then
    return 0
  fi

  local new_hooks="$current_hooks $hook"

  if ! sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" "$mkinitcpio_conf" 2>/dev/null; then
    LAST_ERROR="Failed to update mkinitcpio HOOKS"
    return 1
  fi

  return 0
}

# Gets root btrfs device path.
#
# Uses findmnt to retrieve SOURCE device for root filesystem.
#
# Globals:
#   LAST_ERROR - Set on failure
# Outputs:
#   Device path to stdout (e.g., "/dev/nvme0n1p2")
# Returns:
#   0 on success, 1 on failure, 127 if findmnt missing
get_btrfs_root_device() {
  LAST_ERROR=""

  if ! command_exists findmnt; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  local device
  device=$(findmnt -n -o SOURCE --target / 2>/dev/null)

  if [[ -z "$device" ]]; then
    LAST_ERROR="Failed to find root device"
    return 1
  fi

  # Strip subvolume info (e.g., "/dev/sda1[/@]" -> "/dev/sda1")
  printf '%s\n' "${device%%\[*}"
  return 0
}

# Adds entry to /etc/fstab.
#
# checks for exact line match before adding. Reloads systemd
# daemon after modification if systemctl available.
#
# Arguments:
#   $1 - fstab entry line
#   $2 - Description for error messages
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success (already exists or added), 1 on failure, 2 on invalid args
add_fstab_entry() {
  local entry="${1:-}"
  local description="${2:-}"

  LAST_ERROR=""

  if [[ -z "$entry" ]] || [[ -z "$description" ]]; then
    LAST_ERROR="add_fstab_entry() requires entry and description"
    return 2
  fi

  if [[ ! -f /etc/fstab ]]; then
    LAST_ERROR="/etc/fstab does not exist"
    return 1
  fi

  if grep -qxF "$entry" /etc/fstab 2>/dev/null; then
    return 0
  fi

  if ! printf '\n%s\n' "$entry" | sudo tee -a /etc/fstab >/dev/null 2>&1; then
    LAST_ERROR="Failed to add $description to fstab"
    return 1
  fi

  if command_exists systemctl; then
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  return 0
}

# Sets snapper configuration value.
#
# Auto-creates config if it doesn't exist (only for "root" and "home").
# Uses snapper -c command to set configuration.
#
# Arguments:
#   $1 - Config name (e.g., "root", "home")
#   $2 - Configuration key
#   $3 - Configuration value
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args, 127 if snapper missing
set_snapper_config_value() {
  local config_name="${1:-}"
  local key="${2:-}"
  local value="${3:-}"

  LAST_ERROR=""

  if [[ -z "$config_name" ]] || [[ -z "$key" ]] || [[ -z "$value" ]]; then
    LAST_ERROR="set_snapper_config_value() requires config_name, key, and value"
    return 2
  fi

  if ! command_exists snapper; then
    LAST_ERROR="snapper command not found"
    return 127
  fi

  if ! sudo snapper list-configs 2>/dev/null | grep -q "^$config_name"; then
    case "$config_name" in
    root)
      if ! sudo snapper -c "$config_name" create-config / >/dev/null 2>&1; then
        LAST_ERROR="Failed to create snapper config for root"
        return 1
      fi
      ;;
    home)
      if ! sudo snapper -c "$config_name" create-config /home >/dev/null 2>&1; then
        LAST_ERROR="Failed to create snapper config for home"
        return 1
      fi
      ;;
    *)
      LAST_ERROR="Snapper config '$config_name' does not exist"
      return 1
      ;;
    esac
  fi

  if ! sudo snapper -c "$config_name" set-config "${key}=${value}" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set $key in snapper config '$config_name'"
    return 1
  fi

  return 0
}

# Identifies system bootloader.
#
# Checks for limine binary first, then GRUB config file.
#
# Outputs:
#   Bootloader type to stdout: "grub", "limine", or "unsupported"
# Returns:
#   0 always
detect_bootloader() {
  LAST_ERROR=""

  if [[ -x /usr/bin/limine ]]; then
    printf 'limine\n'
  elif [[ -f /etc/default/grub ]]; then
    printf 'grub\n'
  else
    printf 'unsupported\n'
  fi

  return 0
}

# Updates GRUB kernel command line parameters.
#
# Merges new parameters with existing GRUB_CMDLINE_LINUX_DEFAULT,
# with new params overriding duplicates. Regenerates GRUB config.
# Requires .lib-common.sh sourced for update_config().
#
# Arguments:
#   $@ - Space-separated kernel parameters to add/override
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args, 127 if GRUB not found
update_grub_cmdline() {
  local params="$*"
  local grub_file="/etc/default/grub"

  LAST_ERROR=""

  if [[ -z "$params" ]]; then
    LAST_ERROR="update_grub_cmdline() requires kernel parameters"
    return 2
  fi

  if [[ ! -f "$grub_file" ]]; then
    LAST_ERROR="GRUB configuration file not found: $grub_file"
    return 127
  fi

  # Extract current GRUB_CMDLINE_LINUX_DEFAULT value
  local current_cmdline
  current_cmdline=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' "$grub_file" 2>/dev/null | head -n1)

  # Build new command line (build_cmdline handles deduplication)
  local new_cmdline
  if ! new_cmdline=$(build_cmdline "$current_cmdline" "$params"); then
    LAST_ERROR="Failed to build new command line"
    return 1
  fi

  # Update GRUB config file using update_config from .lib-common.sh
  # Wrap value in quotes as GRUB requires quoted values
  if ! update_config "$grub_file" "GRUB_CMDLINE_LINUX_DEFAULT" "\"$new_cmdline\""; then
    LAST_ERROR="Failed to update GRUB configuration: $LAST_ERROR"
    return 1
  fi

  # Regenerate GRUB config using available mkconfig command
  local mkconfig_cmd
  local grub_cfg_dir
  local grub_cfg_file

  mkconfig_cmd=""
  if command_exists grub-mkconfig; then
    mkconfig_cmd="grub-mkconfig"
    grub_cfg_dir="/boot/grub"
    grub_cfg_file="/boot/grub/grub.cfg"
  elif command_exists grub2-mkconfig; then
    mkconfig_cmd="grub2-mkconfig"
    grub_cfg_dir="/boot/grub2"
    grub_cfg_file="/boot/grub2/grub.cfg"
  else
    LAST_ERROR="GRUB mkconfig command not found (grub-mkconfig or grub2-mkconfig)"
    return 127
  fi

  if [[ ! -d "$grub_cfg_dir" ]]; then
    if ! sudo mkdir -p "$grub_cfg_dir" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create $grub_cfg_dir directory"
      return 1
    fi
  fi

  if ! sudo "$mkconfig_cmd" -o "$grub_cfg_file" >/dev/null 2>&1; then
    LAST_ERROR="Failed to regenerate GRUB configuration with $mkconfig_cmd"
    return 1
  fi

  return 0
}

# Updates Limine kernel command line via drop-in file.
#
# Creates configuration file in /etc/limine-entry-tool.d/ with
# KERNEL_CMDLINE[default]+= directive. Escapes quotes in parameters.
#
# Arguments:
#   $1 - Drop-in filename (e.g., "50-hibernation" or "50-hibernation.conf")
#   $@ - Kernel parameters to add (from $2 onwards)
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args, 127 if limine tools missing
update_limine_cmdline() {
  local dropin_name="${1:-}"

  LAST_ERROR=""

  if [[ -z "$dropin_name" ]]; then
    LAST_ERROR="update_limine_cmdline() requires drop-in filename as first argument"
    return 2
  fi

  shift
  local params="$*"

  if [[ -z "$params" ]]; then
    LAST_ERROR="update_limine_cmdline() requires kernel parameters"
    return 2
  fi

  # Ensure .conf suffix
  [[ "$dropin_name" != *.conf ]] && dropin_name+=".conf"

  local dropin_dir="/etc/limine-entry-tool.d"
  local dropin_file="$dropin_dir/$dropin_name"

  if [[ ! -d "$dropin_dir" ]]; then
    LAST_ERROR="Limine drop-in directory not found: $dropin_dir (install limine-mkinitcpio-hook)"
    return 127
  fi

  # Escape double quotes in parameters for safe embedding
  local escaped_params
  escaped_params=$(printf '%s' "$params" | sed 's/"/\\"/g')

  # Create drop-in file
  if ! sudo mkdir -p "$dropin_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create Limine drop-in directory: $dropin_dir"
    return 1
  fi

  # Note: KERNEL_CMDLINE[default]+= appends to existing parameters
  if ! printf 'KERNEL_CMDLINE[default]+= "%s"\n' "$escaped_params" | sudo tee "$dropin_file" >/dev/null 2>&1; then
    LAST_ERROR="Failed to write Limine drop-in file: $dropin_file"
    return 1
  fi

  # Set proper permissions
  if ! sudo chmod 0644 "$dropin_file" 2>/dev/null; then
    LAST_ERROR="Failed to set permissions on: $dropin_file"
    return 1
  fi

  return 0
}

# Adds dracut module to configuration.
#
# Creates drop-in file in /etc/dracut.conf.d/ with add_dracutmodules directive.
# Idempotent - returns 2 if module already present.
#
# Arguments:
#   $1 - Module name (e.g., "resume", "plymouth")
# Globals:
#   LAST_ERROR - Set on failure or if already present
# Returns:
#   0 on success (added), 1 on failure, 2 (already present), 127 if dracut not found
add_dracut_module() {
  local module="${1:-}"

  LAST_ERROR=""

  if [[ -z "$module" ]]; then
    LAST_ERROR="add_dracut_module() requires module name"
    return 2
  fi

  if ! command_exists dracut; then
    LAST_ERROR="dracut command not found"
    return 127
  fi

  local dropin_dir="/etc/dracut.conf.d"
  local dropin_file="$dropin_dir/${module}-module.conf"

  if ! sudo mkdir -p "$dropin_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create dracut drop-in directory: $dropin_dir"
    return 1
  fi

  if [[ -f "$dropin_file" ]]; then
    if grep -qF "add_dracutmodules+=\" $module \"" "$dropin_file" 2>/dev/null; then
      LAST_ERROR="Module already present"
      return 2
    fi
  fi

  if ! printf 'add_dracutmodules+=" %s "\n' "$module" | sudo tee "$dropin_file" >/dev/null 2>&1; then
    LAST_ERROR="Failed to write dracut module config: $dropin_file"
    return 1
  fi

  if ! sudo chmod 0644 "$dropin_file" 2>/dev/null; then
    LAST_ERROR="Failed to set permissions on: $dropin_file"
    return 1
  fi

  return 0
}

# Identifies system's initramfs generator.
#
# Checks for mkinitcpio first, then dracut.
#
# Outputs:
#   Generator type to stdout: "mkinitcpio", "dracut", or "unsupported"
# Returns:
#   0 always
detect_initramfs_generator() {
  LAST_ERROR=""

  if command_exists mkinitcpio; then
    printf 'mkinitcpio\n'
  elif command_exists dracut; then
    printf 'dracut\n'
  else
    printf 'unsupported\n'
  fi

  return 0
}

# Rebuilds initramfs using detected generator.
#
# For mkinitcpio: Uses mkinitcpio -P (all presets).
# For dracut: Prefers dracut-rebuild if available, else dracut --force --regenerate-all.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 127 if generator unsupported
regenerate_initramfs() {
  LAST_ERROR=""

  local generator
  if ! generator=$(detect_initramfs_generator); then
    LAST_ERROR="Failed to detect initramfs generator"
    return 1
  fi

  case "$generator" in
  mkinitcpio)
    local bootloader
    if ! bootloader=$(detect_bootloader); then
      LAST_ERROR="Failed to detect bootloader"
      return 1
    fi

    if [[ "$bootloader" = "limine" ]]; then
      if ! command_exists limine-mkinitcpio; then
        LAST_ERROR="limine-mkinitcpio command not found (install limine-mkinitcpio-hook)"
        return 127
      fi

      if ! sudo limine-mkinitcpio >/dev/null 2>&1; then
        LAST_ERROR="Failed to regenerate initramfs with limine-mkinitcpio"
        return 1
      fi
    else
      if ! sudo mkinitcpio -P >/dev/null 2>&1; then
        LAST_ERROR="Failed to regenerate initramfs with mkinitcpio"
        return 1
      fi
    fi
    ;;
  dracut)
    if command_exists dracut-rebuild; then
      if ! sudo dracut-rebuild >/dev/null 2>&1; then
        LAST_ERROR="Failed to regenerate initramfs with dracut-rebuild"
        return 1
      fi
    else
      if ! sudo dracut --force --regenerate-all >/dev/null 2>&1; then
        LAST_ERROR="Failed to regenerate initramfs with dracut"
        return 1
      fi
    fi
    ;;
  unsupported)
    LAST_ERROR="No supported initramfs generator found (mkinitcpio or dracut)"
    return 127
    ;;
  *)
    LAST_ERROR="Unknown initramfs generator: $generator"
    return 1
    ;;
  esac

  return 0
}
