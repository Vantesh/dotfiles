#!/usr/bin/env bash
# 01_laptop.sh - Configure laptop optimizations and hibernation
#
# Configures laptop-specific power management settings and sets up
# hibernation with btrfs swapfile support. Includes swap creation,
# initramfs configuration, and bootloader parameter updates.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-snapboot.sh"

readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

# Calculates optimal swap size based on RAM.
#
# Uses formula: swap = sqrt(ram) + ram, minimum 2GB.
# Formula is based on ubuntu hibernation recommendations.
#
# Outputs:
#   Swap size in format "XG" to stdout
# Returns:
#   0 on success
calculate_swap_size() {
  local ram_gb
  ram_gb=$(get_ram_size)

  local sqrt_ram
  sqrt_ram=$(awk "BEGIN {printf \"%.0f\", sqrt($ram_gb)}")

  local swap_gb=$((sqrt_ram + ram_gb))

  [[ $swap_gb -lt 2 ]] && swap_gb=2

  printf '%dG\n' "$swap_gb"
}

# Gets total system RAM in gigabytes.
#
# Outputs:
#   RAM size in GB (rounded up) to stdout
# Returns:
#   0 on success
get_ram_size() {
  awk '/MemTotal/ {printf "%d", ($2 + 1048575) / 1048576}' /proc/meminfo
}

get_gpu_info() {
  lspci -nn 2>/dev/null | grep -Ei "VGA compatible controller|3D controller|Display controller" || printf ''
}

# Gets NVIDIA GPU PCI address.
#
# First tries vendor ID lookup, then falls back to string matching.
#
# Outputs:
#   PCI address (e.g., "0000:01:00.0") to stdout, empty if not found
# Returns:
#   0 on success
get_nvidia_pci_address() {
  local nvidia_pci

  nvidia_pci=$(lspci -Dnnd 10de: 2>/dev/null | awk '{print $1}' | head -n1)

  if [[ -z "$nvidia_pci" ]]; then
    nvidia_pci=$(lspci -D 2>/dev/null | grep -iE "NVIDIA.*(VGA|3D|Display)" | awk '{print $1}' | head -n1)
  fi

  printf '%s\n' "$nvidia_pci"
}

# Creates btrfs swap subvolume and swapfile.
#
# Creates @swap subvolume if missing, mounts it, creates swapfile with
# optimal size, and updates fstab entries.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure
create_btrfs_swap() {
  local temp_mount
  local btrfs_root
  local uuid

  LAST_ERROR=""

  if ! btrfs_root=$(get_btrfs_root_device); then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to get btrfs root device: $error_msg"
    return 1
  fi

  if ! sudo btrfs subvolume list / 2>/dev/null | grep -q "$SWAP_SUBVOL"; then
    temp_mount=$(mktemp -d)
    trap 'mountpoint -q "${temp_mount:-}" 2>/dev/null && sudo umount "${temp_mount}" >/dev/null 2>&1; [[ -d "${temp_mount:-}" ]] && rm -rf "${temp_mount}"' RETURN EXIT ERR

    if ! sudo mount "$btrfs_root" "$temp_mount" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs root device"
      return 1
    fi

    if ! sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swap subvolume"
      return 1
    fi

    log INFO "Created btrfs swap subvolume"
  fi

  if ! mountpoint -q "$SWAP_MOUNT_POINT"; then
    if ! sudo mkdir -p "$SWAP_MOUNT_POINT" 2>/dev/null; then
      LAST_ERROR="Failed to create swap mount point directory"
      return 1
    fi

    if ! sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_root" "$SWAP_MOUNT_POINT" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs swap subvolume"
      return 1
    fi

    log INFO "Mounted btrfs swap subvolume"
  fi

  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    local swap_size
    swap_size=$(calculate_swap_size)

    if ! sudo btrfs filesystem mkswapfile --size "$swap_size" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swapfile"
      return 1
    fi

    log INFO "Created btrfs swapfile: $SWAP_FILE_PATH ($swap_size)"

    if ! uuid=$(blkid -s UUID -o value "$btrfs_root" 2>/dev/null); then
      LAST_ERROR="Failed to get UUID of btrfs root device"
      return 1
    fi

    if ! add_fstab_entry "UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0" "swap subvolume mount"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to add swap subvolume to fstab: $error_msg"
      return 1
    fi
  fi

  if ! swapon --show 2>/dev/null | grep -q "$SWAP_FILE_PATH"; then
    if ! sudo swapon "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to activate swapfile"
      return 1
    fi

    log INFO "Activated btrfs swapfile"

    if ! add_fstab_entry "$SWAP_FILE_PATH none swap defaults 0 0" "swapfile"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to add swapfile to fstab: $error_msg"
      return 1
    fi
  fi

  return 0
}

get_swap_path() {
  swapon --show=NAME --noheadings 2>/dev/null | awk '$1 !~ /\/dev\/zram/ {print; exit}'
}

# Remove both hibernation and quiet boot parameters from a command line string
remove_managed_params() {
  sed -E 's/\b(hibernate\.compressor=[a-z0-9]+|resume=UUID=[a-zA-Z0-9-]+|resume_offset=[0-9]+|quiet|splash|loglevel=[0-9]+|systemd\.show_status=[a-z]+|rd\.udev\.log_level=[0-9]+|vt\.global_cursor_default=[0-9]+)\b//g; s/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$1"
}

# Sets up hibernation support.
#
# Creates swap if needed, configures kernel parameters for resume,
# updates bootloader configuration, and configures initramfs.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success
setup_hibernation() {
  local swap_path
  local generator
  local bootloader
  local hibernation_params
  local resume_uuid
  local resume_offset
  local btrfs_root

  LAST_ERROR=""

  swap_path=$(get_swap_path)

  if [[ -z "$swap_path" ]]; then
    log INFO "No swap found, creating btrfs swapfile"

    if ! create_btrfs_swap; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to create btrfs swap: $error_msg"
      return 1
    fi

    swap_path=$(get_swap_path)

    if [[ -z "$swap_path" ]]; then
      log WARN "Swap still not detected after creation; resume parameters will be skipped"
      hibernation_params=("hibernate.compressor=lz4")
    fi
  fi

  hibernation_params=("hibernate.compressor=lz4")

  if [[ -n "$swap_path" ]]; then
    if [[ -b "$swap_path" ]]; then
      if ! resume_uuid=$(blkid -s UUID -o value "$swap_path" 2>/dev/null); then
        LAST_ERROR="Failed to get UUID for swap device: $swap_path"
        return 1
      fi

      hibernation_params+=("resume=UUID=$resume_uuid")
    elif [[ -f "$swap_path" ]]; then
      if ! btrfs_root=$(get_btrfs_root_device); then
        local error_msg="$LAST_ERROR"
        LAST_ERROR="Failed to get btrfs root device: $error_msg"
        return 1
      fi

      if ! resume_uuid=$(blkid -s UUID -o value "$btrfs_root" 2>/dev/null); then
        LAST_ERROR="Failed to get UUID for btrfs root device"
        return 1
      fi

      if ! resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$swap_path" 2>/dev/null); then
        LAST_ERROR="Failed to get offset for swapfile: $swap_path"
        return 1
      fi

      hibernation_params+=("resume=UUID=$resume_uuid" "resume_offset=$resume_offset")
    else
      log WARN "Swap path $swap_path is neither block device nor file"
    fi
  fi

  if ! generator=$(detect_initramfs_generator); then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to detect initramfs generator: $error_msg"
    return 1
  fi

  if ! bootloader=$(detect_bootloader); then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to detect bootloader: $error_msg"
    return 1
  fi

  case "$bootloader" in
  grub)
    log INFO "Updating GRUB kernel parameters"
    if ! update_grub_cmdline "${hibernation_params[@]}"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to update GRUB kernel command line: $error_msg"
      return 1
    fi
    log INFO "Updated GRUB kernel parameters"
    ;;
  limine)
    if [[ ! -f /etc/limine-entry-tool.d/01-default.conf ]]; then
      if [[ -r /proc/cmdline ]]; then
        local cleaned_params
        cleaned_params=$(remove_managed_params "$(cat /proc/cmdline)")

        if [[ -n "$cleaned_params" ]]; then
          if ! update_limine_cmdline "01-default.conf" "$cleaned_params"; then
            local error_msg="$LAST_ERROR"
            LAST_ERROR="Failed to create default Limine config: $error_msg"
            return 1
          fi
        fi
      else
        LAST_ERROR="/proc/cmdline not readable; cannot create default Limine drop-in"
        return 1
      fi
    fi

    if ! update_limine_cmdline "50-hibernation.conf" --append "${hibernation_params[@]}"; then
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to write Limine hibernation config: $error_msg"
      return 1
    fi
    log INFO "Updated Limine kernel parameters"
    ;;
  *)
    log WARN "Unsupported bootloader ($bootloader), skipping kernel parameter update"
    ;;
  esac

  case "$generator" in
  mkinitcpio)
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    local hooks
    local needs_regen=false

    if [[ ! -f "$mkinitcpio_conf" ]]; then
      LAST_ERROR="mkinitcpio.conf not found"
      return 1
    fi

    hooks=$(sed -nE 's/^[[:space:]]*HOOKS=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

    # Convert to systemd-based initramfs hooks for better hibernation support
    if [[ -n "$hooks" ]]; then
      local new_hooks="$hooks"
      local hooks_changed=false

      # Define hook replacements: "old_hook:new_hook" (empty new_hook means remove)
      local -a hook_replacements=(
        "udev:systemd"
        "usr:systemd"
        "keymap:sd-vconsole"
        "consolefont:sd-vconsole"
        "btrfs-overlayfs:sd-btrfs-overlayfs"
        "resume:"
        "shutdown:sd-shutdown"
        "encrypt:sd-encrypt"
      )

      local old_hook new_hook replacement
      for replacement in "${hook_replacements[@]}"; do
        old_hook="${replacement%%:*}"
        new_hook="${replacement#*:}"

        if [[ "$new_hooks" =~ (^|[[:space:]])${old_hook}([[:space:]]|$) ]]; then
          if [[ -n "$new_hook" ]]; then
            new_hooks=$(echo "$new_hooks" | sed -E "s/(^|[[:space:]])${old_hook}([[:space:]]|$)/\1${new_hook}\2/")
            log INFO "Replaced '${old_hook}' with '${new_hook}' hook"
          else
            new_hooks=$(echo "$new_hooks" | sed -E "s/(^|[[:space:]])${old_hook}([[:space:]]|$)/\1\2/")
            log INFO "Removed '${old_hook}' hook (handled by systemd)"
          fi
          hooks_changed=true
        fi
      done

      # Clean up extra spaces and remove duplicates while preserving order
      new_hooks=$(echo "$new_hooks" | tr -s ' ' | sed 's/^ //; s/ $//')

      # Remove duplicate hooks while preserving order
      if [[ "$hooks_changed" == true ]]; then
        local -a hook_array seen_hooks final_hooks
        read -ra hook_array <<<"$new_hooks"

        for hook in "${hook_array[@]}"; do
          local found=false
          for seen in "${seen_hooks[@]}"; do
            if [[ "$hook" == "$seen" ]]; then
              found=true
              break
            fi
          done
          if [[ "$found" == false ]]; then
            seen_hooks+=("$hook")
            final_hooks+=("$hook")
          fi
        done

        new_hooks="${final_hooks[*]}"
      fi

      if [[ "$hooks_changed" == true ]]; then
        if ! sudo sed -i -E "s|^[[:space:]]*HOOKS=\(.*\)|HOOKS=($new_hooks)|" "$mkinitcpio_conf" 2>/dev/null; then
          LAST_ERROR="Failed to update mkinitcpio HOOKS"
          return 1
        fi
        log INFO "Converted to systemd-based initramfs hooks"
        needs_regen=true
      fi
    fi

    # Get GPU info early to determine module order
    local gpu_info
    gpu_info=$(get_gpu_info)

    local modules
    modules=$(sed -nE 's/^[[:space:]]*MODULES=\((.*)\)[[:space:]]*$/\1/p' "$mkinitcpio_conf" 2>/dev/null | head -n1)

    # Build ordered list of modules ensuring correct order
    # CRITICAL: NVIDIA modules MUST come before compression modules for hibernation to work
    local -a current_modules
    local nvidia_modules=("nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm")
    local compression_modules=("lz4" "lz4_compress")
    local needs_reorder=false
    local has_nvidia=false

    read -ra current_modules <<<"$modules"

    if [[ "$gpu_info" = *"NVIDIA Corporation"* ]]; then
      has_nvidia=true
    fi

    # Check if we have both NVIDIA and compression modules, and if compression comes first
    if [[ "$has_nvidia" = true ]]; then
      local first_nvidia_idx=-1
      local first_compression_idx=-1

      for i in "${!current_modules[@]}"; do
        local mod="${current_modules[$i]}"

        # Find first NVIDIA module index
        if [[ $first_nvidia_idx -eq -1 ]]; then
          for nvidia_mod in "${nvidia_modules[@]}"; do
            if [[ "$mod" = "$nvidia_mod" ]]; then
              first_nvidia_idx=$i
              break
            fi
          done
        fi

        # Find first compression module index
        if [[ $first_compression_idx -eq -1 ]]; then
          for comp_mod in "${compression_modules[@]}"; do
            if [[ "$mod" = "$comp_mod" ]]; then
              first_compression_idx=$i
              break
            fi
          done
        fi
      done

      # If compression modules exist and come before NVIDIA modules (or NVIDIA doesn't exist yet), reorder
      if [[ $first_compression_idx -ne -1 ]] && { [[ $first_nvidia_idx -eq -1 ]] || [[ $first_compression_idx -lt $first_nvidia_idx ]]; }; then
        needs_reorder=true
      fi
    fi

    # Rebuild module list with correct order
    if [[ "$needs_reorder" = true ]] || [[ "$has_nvidia" = true ]]; then
      local -a final_modules=()
      local -a other_modules=()
      local -a nvidia_to_add=()
      local -a compression_to_add=()

      # Separate modules into categories
      for mod in "${current_modules[@]}"; do
        local is_nvidia=false
        local is_compression=false

        for nvidia_mod in "${nvidia_modules[@]}"; do
          if [[ "$mod" = "$nvidia_mod" ]]; then
            is_nvidia=true
            break
          fi
        done

        if [[ "$is_nvidia" = false ]]; then
          for comp_mod in "${compression_modules[@]}"; do
            if [[ "$mod" = "$comp_mod" ]]; then
              is_compression=true
              break
            fi
          done
        fi

        if [[ "$is_nvidia" = false ]] && [[ "$is_compression" = false ]]; then
          other_modules+=("$mod")
        fi
      done

      # Determine which modules to add
      if [[ "$has_nvidia" = true ]]; then
        for nvidia_mod in "${nvidia_modules[@]}"; do
          local found=false
          for mod in "${current_modules[@]}"; do
            if [[ "$mod" = "$nvidia_mod" ]]; then
              found=true
              break
            fi
          done
          if [[ "$found" = false ]]; then
            nvidia_to_add+=("$nvidia_mod")
          fi
        done
      fi

      for comp_mod in "${compression_modules[@]}"; do
        local found=false
        for mod in "${current_modules[@]}"; do
          if [[ "$mod" = "$comp_mod" ]]; then
            found=true
            break
          fi
        done
        if [[ "$found" = false ]]; then
          compression_to_add+=("$comp_mod")
        fi
      done

      # Build final module list: other modules + NVIDIA modules + compression modules
      final_modules=("${other_modules[@]}")

      if [[ "$has_nvidia" = true ]]; then
        # Add existing NVIDIA modules first
        for nvidia_mod in "${nvidia_modules[@]}"; do
          for mod in "${current_modules[@]}"; do
            if [[ "$mod" = "$nvidia_mod" ]]; then
              final_modules+=("$mod")
              break
            fi
          done
        done
        # Then add any missing NVIDIA modules
        final_modules+=("${nvidia_to_add[@]}")
      fi

      # Add existing compression modules
      for comp_mod in "${compression_modules[@]}"; do
        for mod in "${current_modules[@]}"; do
          if [[ "$mod" = "$comp_mod" ]]; then
            final_modules+=("$mod")
            break
          fi
        done
      done
      # Then add any missing compression modules
      final_modules+=("${compression_to_add[@]}")

      # Only update if something changed
      if [[ "${final_modules[*]}" != "${current_modules[*]}" ]]; then
        local new_modules_str="${final_modules[*]}"

        if ! sudo sed -i -E "s|^[[:space:]]*MODULES=\(.*\)|MODULES=($new_modules_str)|" "$mkinitcpio_conf" 2>/dev/null; then
          LAST_ERROR="Failed to update mkinitcpio MODULES"
          return 1
        fi

        if [[ "$needs_reorder" = true ]]; then
          log INFO "Reordered mkinitcpio MODULES (NVIDIA before compression)"
        fi

        if [[ ${#nvidia_to_add[@]} -gt 0 ]] || [[ ${#compression_to_add[@]} -gt 0 ]]; then
          local -a added=("${nvidia_to_add[@]}" "${compression_to_add[@]}")
          log INFO "Updated mkinitcpio MODULES (added ${added[*]})"
        fi

        needs_regen=true
      fi
    fi

    if [[ "$needs_regen" = true ]]; then
      log INFO "Regenerating initramfs (this may take a moment)..."
      if ! regenerate_initramfs; then
        local error_msg="$LAST_ERROR"
        LAST_ERROR="Failed to regenerate initramfs: $error_msg"
        return 1
      fi
      log INFO "Regenerated initramfs"
    fi
    ;;
  dracut)
    local dracut_result=0
    local needs_initramfs_regen=false

    add_dracut_module "resume" || dracut_result=$?

    case $dracut_result in
    0)
      log INFO "Added dracut resume module"
      needs_initramfs_regen=true
      ;;
    2)
      log SKIP "Dracut resume module already configured"
      ;;
    *)
      local error_msg="$LAST_ERROR"
      LAST_ERROR="Failed to add dracut resume module: $error_msg"
      return 1
      ;;
    esac

    if [[ "$needs_initramfs_regen" = true ]]; then
      log INFO "Regenerating initramfs (this may take a moment)..."
      if ! regenerate_initramfs; then
        local error_msg="$LAST_ERROR"
        LAST_ERROR="Failed to regenerate initramfs: $error_msg"
        return 1
      fi
      log INFO "Regenerated initramfs"
    else
      log SKIP "No initramfs changes, skipping regeneration"
    fi
    ;;
  unsupported)
    log WARN "No supported initramfs generator found, skipping initramfs configuration"
    ;;
  *)
    log WARN "Unknown initramfs generator ($generator), skipping initramfs configuration"
    ;;
  esac

  return 0
}

main() {
  local gpu_info
  local ram_size

  # Laptop optimizations (always run if on a laptop)
  if is_laptop; then
    print_box "Laptop"
    log STEP "Laptop Optimizations"

    if command_exists powertop; then
      if sudo powertop --auto-tune >/dev/null 2>&1; then
        log INFO "Applied powertop auto-tune"
      else
        log WARN "Failed to apply powertop auto-tune"
      fi
    fi
  fi

  # Exit early if hibernation setup is disabled
  if [[ "${SETUP_HIBERNATION:-1}" != "1" ]]; then
    log INFO "Skipping hibernation setup (disabled in configuration)"
    return 0
  fi

  if ! check_btrfs; then
    log SKIP "Root filesystem is not btrfs, skipping hibernation setup"
    return 0
  fi

  if ! is_laptop; then
    log SKIP "Not a laptop, skipping hibernation setup"
    return 0
  fi

  log STEP "Hibernation Setup"

  local generator
  local bootloader

  if ! generator=$(detect_initramfs_generator); then
    die "Failed to detect initramfs generator: $LAST_ERROR"
  fi

  if ! bootloader=$(detect_bootloader); then
    die "Failed to detect bootloader: $LAST_ERROR"
  fi

  if ! create_backup "/etc/fstab"; then
    die "Failed to backup /etc/fstab: $LAST_ERROR"
  fi

  if [[ "$generator" = "mkinitcpio" ]] && [[ -f /etc/mkinitcpio.conf ]]; then
    if ! create_backup "/etc/mkinitcpio.conf"; then
      die "Failed to backup /etc/mkinitcpio.conf: $LAST_ERROR"
    fi
  fi

  if [[ "$bootloader" = "grub" ]] && [[ -f /etc/default/grub ]]; then
    if ! create_backup "/etc/default/grub"; then
      die "Failed to backup /etc/default/grub: $LAST_ERROR"
    fi
  fi

  if ! setup_hibernation; then
    local error_msg="$LAST_ERROR"
    local restore_failures=0

    restore_backup "/etc/fstab" >/dev/null 2>&1 || ((restore_failures++))

    if [[ "$generator" = "mkinitcpio" ]] && [[ -f /etc/mkinitcpio.conf ]]; then
      restore_backup "/etc/mkinitcpio.conf" >/dev/null 2>&1 || ((restore_failures++))
    fi

    if [[ "$bootloader" = "grub" ]] && [[ -f /etc/default/grub ]]; then
      restore_backup "/etc/default/grub" >/dev/null 2>&1 || ((restore_failures++))
    fi

    if [[ $restore_failures -eq 0 ]]; then
      die "Hibernation setup failed: $error_msg (backups restored)"
    else
      die "Hibernation setup failed: $error_msg (warning: some backups may not have been restored)"
    fi
  fi

  if ! write_system_config "/etc/systemd/sleep.conf.d/hibernation.conf" <<'EOF'; then
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateMode=shutdown
EOF
    die "Failed to write systemd sleep config: $LAST_ERROR"
  fi
  log INFO "Configured systemd sleep"

  if ! write_system_config "/etc/systemd/logind.conf.d/hibernation.conf" <<'EOF'; then
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=suspend-then-hibernate
EOF
    die "Failed to write systemd logind config: $LAST_ERROR"
  fi
  log INFO "Configured systemd logind"

  if ! write_system_config "/etc/tmpfiles.d/disable-usb-wake.conf" <<'EOF'; then
# Disable USB wakeup devices
#    Path                  Mode UID  GID  Age Argument
w    /proc/acpi/wakeup     -    -    -    -   XHC
EOF
    die "Failed to write USB wakeup config: $LAST_ERROR"
  fi
  log INFO "Configured USB wakeup disable"

  ram_size=$(get_ram_size)
  if [[ "$ram_size" -gt 30 ]]; then
    if ! write_system_config "/etc/tmpfiles.d/hibernation_image_size.conf" <<'EOF'; then
#    Path                   Mode UID  GID  Age Argument
w    /sys/power/image_size  -    -    -    -   0
EOF
      die "Failed to write hibernation image size config: $LAST_ERROR"
    fi
    log INFO "Configured hibernation image size"
  fi

  gpu_info=$(get_gpu_info)
  if [[ "$gpu_info" = *"NVIDIA Corporation"* ]]; then
    log INFO "Detected NVIDIA GPU, configuring power management"

    local services=(
      "nvidia-suspend-then-hibernate.service"
      "nvidia-hibernate.service"
      "nvidia-suspend.service"
      "nvidia-resume.service"
    )

    local svc
    for svc in "${services[@]}"; do
      if ! systemctl --quiet is-enabled "$svc" 2>/dev/null; then
        if ! enable_service "$svc" "system"; then
          log WARN "Failed to enable $svc: $LAST_ERROR"
        fi
      fi
    done

    local nvidia_pci
    nvidia_pci=$(get_nvidia_pci_address)

    if [[ -n "$nvidia_pci" ]]; then
      write_system_config "/etc/tmpfiles.d/nvidia_pm.conf" <<EOF || die "Failed to write NVIDIA power management config: $LAST_ERROR"
# NVIDIA power management
w /sys/bus/pci/devices/${nvidia_pci}/power/control - - - - auto
EOF
      log INFO "Configured NVIDIA power management for PCI $nvidia_pci"
    else
      log WARN "Failed to detect NVIDIA GPU PCI address"
    fi

  fi

  log INFO "Hibernation setup completed"
}

main "$@"
