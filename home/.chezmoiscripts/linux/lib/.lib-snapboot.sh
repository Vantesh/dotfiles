#!/usr/bin/env bash
# .lib-snapboot.sh - Bootloader and filesystem configuration management
# Exit codes: 0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)
#
# Bootloader Functions:
#   build_cmdline <current> <new_params> - Merge kernel parameters (returns via stdout)
#   detect_bootloader - Detect bootloader type: "grub", "limine", or "unsupported"
#   detect_initramfs_generator - Detect initramfs generator: "mkinitcpio", "dracut", or "unsupported"
#   update_grub_cmdline <params...> - Update GRUB kernel command line
#   update_limine_cmdline <dropin_name> <params...> - Update Limine kernel command line
#   add_dracut_module <module_name> - Add dracut module to configuration
#   regenerate_initramfs - Regenerate initramfs using detected generator
#
# Filesystem Functions:
#   check_btrfs - Check if root filesystem is btrfs
#   get_btrfs_root_device - Get root btrfs device path (returns via stdout)
#   add_fstab_entry <entry> <description> - Add entry to /etc/fstab (idempotent)
#   set_snapper_config_value <config_name> <key> <value> - Set snapper config value
#
# Initramfs Functions:
#   add_mkinitcpio_hook <hook_name> - Add hook to mkinitcpio.conf HOOKS array (idempotent)

export LAST_ERROR="${LAST_ERROR:-}"

# build_cmdline merges current and new kernel parameters, overriding duplicates.
# Arguments:
#   $1 - Current kernel command line (space-separated)
#   $2 - New parameters to add/override (space-separated)
# Returns: 0 on success, 2 on missing arguments
# Output: Merged command line to stdout
build_cmdline() {
  local current="${1:-}"
  local new_params="${2:-}"

  LAST_ERROR=""

  if [[ "$current" = "" ]] && [[ "$new_params" = "" ]]; then
    LAST_ERROR="build_cmdline() requires at least one argument"
    return 2
  fi

  declare -A params_map
  local -a ordered_keys=()
  local param key

  # Parse current parameters - intentional word splitting
  if [[ "$current" != "" ]]; then
    # shellcheck disable=SC2086
    while IFS= read -r param; do
      [[ "$param" = "" ]] && continue
      key="${param%%=*}"
      if [[ -z "${params_map[$key]+x}" ]]; then
        ordered_keys+=("$key")
      fi
      params_map["$key"]="$param"
    done < <(printf '%s\n' $current)
  fi

  # Parse new parameters - intentional word splitting (override existing)
  if [[ "$new_params" != "" ]]; then
    # shellcheck disable=SC2086
    while IFS= read -r param; do
      [[ "$param" = "" ]] && continue
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

# check_btrfs verifies that root filesystem is btrfs.
# Returns: 0 if root is btrfs, 1 if not, 127 if findmnt missing
check_btrfs() {
  LAST_ERROR=""

  if ! command -v findmnt >/dev/null 2>&1; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  if ! findmnt -n -o FSTYPE / 2>/dev/null | grep -q "^btrfs$"; then
    LAST_ERROR="Root filesystem is not btrfs"
    return 1
  fi

  return 0
}

# add_mkinitcpio_hook adds a hook to mkinitcpio.conf HOOKS array.
# Arguments:
#   $1 - hook name to add
# Returns: 0 on success (added or already present), 1 on failure, 2 on invalid args
add_mkinitcpio_hook() {
  local hook="${1:-}"
  local mkinitcpio_conf="/etc/mkinitcpio.conf"

  LAST_ERROR=""

  if [[ "$hook" = "" ]]; then
    LAST_ERROR="add_mkinitcpio_hook() requires hook name"
    return 2
  fi

  if [[ ! -f "$mkinitcpio_conf" ]]; then
    LAST_ERROR="mkinitcpio.conf not found"
    return 1
  fi

  # Extract current HOOKS line
  local current_hooks
  current_hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

  if [[ "$current_hooks" = "" ]]; then
    LAST_ERROR="Failed to parse HOOKS from mkinitcpio.conf"
    return 1
  fi

  # Check if hook already present (idempotent) - use word boundaries to avoid partial matches
  if [[ " $current_hooks " = *" $hook "* ]]; then
    return 0
  fi

  # Add hook at the end
  local new_hooks="$current_hooks $hook"

  if ! sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" "$mkinitcpio_conf" 2>/dev/null; then
    LAST_ERROR="Failed to update mkinitcpio HOOKS"
    return 1
  fi

  return 0
}

# get_btrfs_root_device returns the device path for root btrfs filesystem.
# Returns: 0 on success, 1 on failure, 127 if findmnt missing
# Output: Device path to stdout (e.g., "/dev/nvme0n1p2")
get_btrfs_root_device() {
  LAST_ERROR=""

  if ! command -v findmnt >/dev/null 2>&1; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  local device
  device=$(findmnt -n -o SOURCE --target / 2>/dev/null)

  if [[ "$device" = "" ]]; then
    LAST_ERROR="Failed to find root device"
    return 1
  fi

  # Strip subvolume info (e.g., "/dev/sda1[/@]" -> "/dev/sda1")
  printf '%s\n' "${device%%\[*}"
  return 0
}

# add_fstab_entry adds an entry to /etc/fstab if not already present.
# Arguments:
#   $1 - fstab entry line
#   $2 - description for error messages
# Returns: 0 on success (already exists or added), 1 on failure, 2 on invalid args
add_fstab_entry() {
  local entry="${1:-}"
  local description="${2:-}"

  LAST_ERROR=""

  if [[ "$entry" = "" ]] || [[ "$description" = "" ]]; then
    LAST_ERROR="add_fstab_entry() requires entry and description"
    return 2
  fi

  if [[ ! -f /etc/fstab ]]; then
    LAST_ERROR="/etc/fstab does not exist"
    return 1
  fi

  # Check if entry already exists (idempotent) - exact line match
  if grep -qxF "$entry" /etc/fstab 2>/dev/null; then
    return 0
  fi

  # Add entry with newline separator
  if ! printf '\n%s\n' "$entry" | sudo tee -a /etc/fstab >/dev/null 2>&1; then
    LAST_ERROR="Failed to add $description to fstab"
    return 1
  fi

  # Reload systemd if available
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  return 0
}

# set_snapper_config_value sets a configuration value for a snapper config.
# Creates the config if it doesn't exist (only for "root" and "home").
# Arguments:
#   $1 - config name (e.g., "root", "home")
#   $2 - configuration key
#   $3 - configuration value
# Returns: 0 on success, 1 on failure, 2 on invalid args, 127 if snapper missing
set_snapper_config_value() {
  local config_name="${1:-}"
  local key="${2:-}"
  local value="${3:-}"

  LAST_ERROR=""

  if [[ "$config_name" = "" ]] || [[ "$key" = "" ]] || [[ "$value" = "" ]]; then
    LAST_ERROR="set_snapper_config_value() requires config_name, key, and value"
    return 2
  fi

  if ! command -v snapper >/dev/null 2>&1; then
    LAST_ERROR="snapper command not found"
    return 127
  fi

  # Check if config exists
  if ! sudo snapper list-configs 2>/dev/null | grep -q "^$config_name"; then
    # Auto-create standard configs
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

  # Set configuration value
  if ! sudo snapper -c "$config_name" set-config "${key}=${value}" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set $key in snapper config '$config_name'"
    return 1
  fi

  return 0
}

# detect_bootloader identifies the system bootloader.
# Returns: 0 on success
# Output: "grub", "limine", or "unsupported" to stdout
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

# update_grub_cmdline updates GRUB kernel command line parameters.
# Merges new parameters with existing GRUB_CMDLINE_LINUX_DEFAULT (deduplicates by key).
# Arguments: Space-separated kernel parameters to add/override
# Returns: 0 on success, 1 on failure, 2 on invalid args, 127 if GRUB not found
update_grub_cmdline() {
  local params="$*"
  local grub_file="/etc/default/grub"

  LAST_ERROR=""

  if [[ "$params" = "" ]]; then
    LAST_ERROR="update_grub_cmdline() requires kernel parameters"
    return 2
  fi

  if [[ ! -f "$grub_file" ]]; then
    LAST_ERROR="GRUB configuration file not found: $grub_file"
    return 127
  fi

  # Extract current GRUB_CMDLINE_LINUX_DEFAULT
  local current_cmdline
  current_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" 2>/dev/null | sed 's/.*="\(.*\)"/\1/')

  # Build new command line (build_cmdline handles deduplication)
  local new_cmdline
  if ! new_cmdline=$(build_cmdline "$current_cmdline" "$params"); then
    LAST_ERROR="Failed to build new command line"
    return 1
  fi

  # Update GRUB config file
  if ! sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"|" "$grub_file" 2>/dev/null; then
    LAST_ERROR="Failed to update GRUB configuration file"
    return 1
  fi

  # Regenerate GRUB config
  if ! sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
    LAST_ERROR="Failed to regenerate GRUB configuration"
    return 1
  fi

  return 0
}

# update_limine_cmdline updates Limine kernel command line via drop-in file.
# Arguments:
#   $1 - Drop-in filename (e.g., "50-hibernation.conf" or "50-hibernation")
#   $@ - Kernel parameters to add
# Returns: 0 on success, 1 on failure, 2 on invalid args, 127 if limine tools missing
update_limine_cmdline() {
  local dropin_name="${1:-}"

  LAST_ERROR=""

  if [[ "$dropin_name" = "" ]]; then
    LAST_ERROR="update_limine_cmdline() requires drop-in filename as first argument"
    return 2
  fi

  shift
  local params="$*"

  if [[ "$params" = "" ]]; then
    LAST_ERROR="update_limine_cmdline() requires kernel parameters"
    return 2
  fi

  # Ensure .conf suffix
  [[ "$dropin_name" != *.conf ]] && dropin_name+=".conf"

  local dropin_dir="/etc/limine-entry-tool.d"
  local dropin_file="$dropin_dir/$dropin_name"

  # Check if limine-entry-tool directory exists
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

  # Write drop-in configuration
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

# add_dracut_module adds a dracut module to configuration.
# Creates drop-in file in /etc/dracut.conf.d/ with add_dracutmodules+=" <module> "
# Arguments:
#   $1 - module name (e.g., "resume")
# Returns: 0 on success (added or already present), 1 on failure, 2 on invalid args, 127 if dracut not found
add_dracut_module() {
  local module="${1:-}"

  LAST_ERROR=""

  if [[ "$module" = "" ]]; then
    LAST_ERROR="add_dracut_module() requires module name"
    return 2
  fi

  if ! command -v dracut >/dev/null 2>&1; then
    LAST_ERROR="dracut command not found"
    return 127
  fi

  local dropin_dir="/etc/dracut.conf.d"
  local dropin_file="$dropin_dir/${module}-module.conf"

  # Create drop-in directory if needed
  if ! sudo mkdir -p "$dropin_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create dracut drop-in directory: $dropin_dir"
    return 1
  fi

  if [[ -f "$dropin_file" ]]; then
    if grep -qF "add_dracutmodules+=\" $module \"" "$dropin_file" 2>/dev/null; then
      return 0
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

# detect_initramfs_generator identifies the system's initramfs tool.
# Returns: 0 on success
# Output: "mkinitcpio", "dracut", or "unsupported" to stdout
detect_initramfs_generator() {
  LAST_ERROR=""

  if command -v mkinitcpio >/dev/null 2>&1; then
    printf 'mkinitcpio\n'
  elif command -v dracut >/dev/null 2>&1; then
    printf 'dracut\n'
  else
    printf 'unsupported\n'
  fi

  return 0
}

# regenerate_initramfs rebuilds initramfs using detected generator.
# Returns: 0 on success, 1 on failure, 127 if generator unsupported
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
      if ! command -v limine-mkinitcpio >/dev/null 2>&1; then
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
    # dracut --force regenerates all installed kernels
    if ! sudo dracut --force >/dev/null 2>&1; then
      LAST_ERROR="Failed to regenerate initramfs with dracut"
      return 1
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
