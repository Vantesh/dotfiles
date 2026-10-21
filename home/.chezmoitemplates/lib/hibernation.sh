#!/usr/bin/env bash
# Hibernation helpers; include after common.sh and snapboot.sh.

readonly SWAP_SUBVOL="@swap"
readonly SWAP_MOUNT_POINT="/swap"
readonly SWAP_FILE_PATH="/swap/swapfile"

readonly HIBERNATION_SWAP_OWNER="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/hibernation.swapfile"

# Only the repository's exact layout is managed. Zram is never a resume target.
# Return 3 for independently managed swap, 1 when inspection fails.
check_hibernation_swap_policy() {
  local active table units unit path source target filesystem options extra
  active=$(swapon --show=NAME --noheadings --raw 2>/dev/null) || return 1
  table=$(findmnt --fstab --tab-file /etc/fstab -rn -o SOURCE,TARGET,FSTYPE,OPTIONS 2>&1) || {
    [[ -z "$table" ]] && ! grep -qE '^[[:space:]]*[^#[:space:]]' /etc/fstab || return 1
  }
  while read -r source target filesystem options extra; do
    [[ -n "$source" ]] || continue
    [[ -n "$options" && -z "$extra" && "$source" != findmnt:* ]] || return 1
    if [[ "$filesystem" = swap ]]; then
      active+=$'\n'"$source"
    fi
  done <<<"$table"
  # Include inactive, independently configured systemd swap units too.
  units=$(systemctl list-unit-files --type=swap --no-legend --no-pager 2>/dev/null) || return 1
  while read -r unit extra; do
    [[ -n "$unit" ]] || continue
    path=$(systemctl show --property=What --value "$unit" 2>/dev/null) || return 1
    [[ -n "$path" ]] || return 1
    active+=$'\n'"$path"
  done <<<"$units"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$path" =~ ^/dev/zram[0-9]+$ ]] && continue
    if [[ "$path" != "$SWAP_FILE_PATH" ]]; then
      log INFO "Existing independently managed swap ($path); configure hibernation manually (left untouched)"
      return 3
    fi
  done <<<"$active"
}

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

# Returns 0 for an equivalent entry, 2 if missing, or 1 for a conflict.
# swap_subvol_id is discovered from this filesystem, not assumed from fstab.
_check_hibernation_fstab_entry() {
  local wanted_source wanted_target wanted_type _
  read -r wanted_source wanted_target wanted_type _ <<<"$1"
  local entries source target filesystem options extra source_uuid option
  local found=false has_subvol valid table_status=0
  local -a mount_options

  if [[ ! -r /etc/fstab ]]; then
    LAST_ERROR="Cannot read /etc/fstab; check it before configuring swap"
    return 1
  fi
  entries=$(LC_ALL=C findmnt --fstab --tab-file /etc/fstab -rn -o SOURCE,TARGET,FSTYPE,OPTIONS 2>&1) || table_status="$?"
  if [[ "$table_status" != 0 ]]; then
    # findmnt returns 1 for an empty table as well as for errors.
    if [[ "$table_status" != 1 || -n "$entries" ]] || ! entries=$(awk '!/^[[:space:]]*(#|$)/ {print}' /etc/fstab) || [[ -n "$entries" ]]; then
      LAST_ERROR="Cannot parse /etc/fstab; check it before configuring swap"
      return 1
    fi
  fi

  while read -r source target filesystem options extra; do
    [[ -n "$source" ]] || continue
    # Parse errors can accompany a successful findmnt result for other entries.
    if [[ "$source" = findmnt:* || -z "$options" || -n "$extra" ]]; then
      LAST_ERROR="Cannot parse /etc/fstab; fix malformed entries before configuring swap"
      return 1
    fi
    if [[ "$target" = /* ]]; then
      target=$(readlink -m -- "$target") || return 1
    fi
    if [[ "$source" = /* && "$source" != /dev/* ]]; then
      source=$(readlink -m -- "$source") || return 1
    fi
    if [[ "$wanted_type" = btrfs ]]; then
      [[ "$target" = "$wanted_target" ]] || continue
      valid=true
      source_uuid=""
      case "$source" in
      UUID=*) source_uuid="${source#UUID=}" ;;
      /dev/*) source_uuid=$(lsblk -dnro UUID "$source" 2>/dev/null) || valid=false ;;
      *) valid=false ;;
      esac
      [[ -n "$source_uuid" && "${source_uuid,,}" = "${wanted_source#UUID=}" && "$filesystem" = btrfs && -z "$extra" ]] || valid=false
      has_subvol=false
      IFS=',' read -r -a mount_options <<<"$options"
      for option in "${mount_options[@]}"; do
        case "$option" in
        subvol=*)
          has_subvol=true
          [[ "$option" = "subvol=$SWAP_SUBVOL" || "$option" = "subvol=/$SWAP_SUBVOL" ]] || valid=false
          ;;
        subvolid=*)
          has_subvol=true
          [[ -n "${swap_subvol_id:-}" && "$option" = "subvolid=$swap_subvol_id" ]] || valid=false
          ;;
        ro | noauto | bind | rbind) valid=false ;;
        esac
      done
      [[ "$has_subvol" = true && "$valid" = true ]] || {
        LAST_ERROR="Conflicting /etc/fstab entry for $wanted_target; use the root filesystem's $SWAP_SUBVOL subvolume"
        return 1
      }
    else
      [[ "$source" = "$wanted_source" || "$target" = "$wanted_source" ]] || continue
      if [[ "$source" != "$wanted_source" || "$filesystem" != swap || ("$target" != none && "$target" != swap) || -n "$extra" || ",$options," = *,noauto,* ]]; then
        LAST_ERROR="Conflicting /etc/fstab entry for $wanted_source; check its swapfile entry"
        return 1
      fi
    fi
    found=true
  done <<<"$entries"

  [[ "$found" = true ]] && return 0
  return 2
}

# Require an exact mount and filesystem root; SOURCE alone can hide bind mounts.
_validate_hibernation_swap_mount() {
  local uuid="$1"
  local identity file_mount links mount_target="$SWAP_FILE_PATH"
  if ! identity=$(findmnt -rn -o TARGET,FSTYPE,UUID,FSROOT --mountpoint "$SWAP_MOUNT_POINT" 2>/dev/null) ||
    [[ "$identity" != "$SWAP_MOUNT_POINT btrfs $uuid /$SWAP_SUBVOL" ]]; then
    LAST_ERROR="$SWAP_MOUNT_POINT must mount the root filesystem's /$SWAP_SUBVOL subvolume; check findmnt before retrying"
    return 1
  fi
  if [[ ! -e "$SWAP_FILE_PATH" && ! -L "$SWAP_FILE_PATH" ]]; then
    mount_target="$SWAP_MOUNT_POINT"
  fi
  if ! file_mount=$(findmnt -rn -o TARGET --target "$mount_target" 2>/dev/null) || [[ "$file_mount" != "$SWAP_MOUNT_POINT" ]]; then
    LAST_ERROR="$SWAP_FILE_PATH is on a nested or unverifiable mount; remove the conflicting mount before retrying"
    return 1
  fi
  if [[ -L "$SWAP_FILE_PATH" ]] || { [[ -e "$SWAP_FILE_PATH" ]] && { [[ ! -f "$SWAP_FILE_PATH" ]] || ! links=$(stat -c %h -- "$SWAP_FILE_PATH") || [[ "$links" != 1 ]]; }; }; then
    LAST_ERROR="$SWAP_FILE_PATH must be a regular, non-symlink file with one link"
    return 1
  fi
}

# Adds a hibernation fstab entry with invocation-local rollback tracking.
#
# Snapshots only before the first missing entry. Tracks expected append results
# so rollback does not overwrite unrelated changes.
#
# Arguments:
#   $1 - fstab entry line
#   $2 - Description for error messages
# Globals:
#   LAST_ERROR - Set on failure
#   fstab_snapshot_dir - Transaction snapshot directory
#   fstab_changed - Set when an append is confirmed
# Returns:
#   0 on success, 1 on failure
_add_hibernation_fstab_entry() {
  local entry="$1"
  local description="$2"

  LAST_ERROR=""

  local entry_status=0
  _check_hibernation_fstab_entry "$entry" || entry_status="$?"
  case "$entry_status" in
  0) return 0 ;;
  2) ;;
  *) return 1 ;;
  esac

  if [[ -z "$fstab_snapshot_dir" ]]; then
    if ! fstab_snapshot_dir="$(mktemp -d)"; then
      LAST_ERROR="Failed to create temporary fstab snapshot directory"
      return 1
    fi

    if ! cp -- /etc/fstab "$fstab_snapshot_dir/before" ||
      ! cp -- "$fstab_snapshot_dir/before" "$fstab_snapshot_dir/expected"; then
      LAST_ERROR="Failed to snapshot /etc/fstab"
      return 1
    fi
  fi

  if ! cmp -s -- "$fstab_snapshot_dir/expected" /etc/fstab; then
    LAST_ERROR="/etc/fstab changed before append; refusing to overwrite unrelated changes"
    return 1
  fi

  if ! cp -- "$fstab_snapshot_dir/expected" "$fstab_snapshot_dir/next" ||
    ! printf '\n%s\n' "$entry" >>"$fstab_snapshot_dir/next"; then
    LAST_ERROR="Failed to prepare expected fstab contents"
    return 1
  fi

  local append_result=0
  add_fstab_entry "$entry" "$description" || append_result="$?"
  local error_msg="$LAST_ERROR"

  if cmp -s -- "$fstab_snapshot_dir/next" /etc/fstab; then
    # Read by the calling hibernation transaction's rollback path (Bash dynamic scope).
    # shellcheck disable=SC2034
    fstab_changed=true
    if ! cp -- "$fstab_snapshot_dir/next" "$fstab_snapshot_dir/expected"; then
      LAST_ERROR="Failed to record updated fstab contents"
      return 1
    fi
  elif ! cmp -s -- "$fstab_snapshot_dir/expected" /etc/fstab; then
    LAST_ERROR="/etc/fstab changed unexpectedly; refusing to roll back unrelated changes"
    return 1
  fi

  LAST_ERROR="$error_msg"
  return "$append_result"
}

# Creates btrfs swap subvolume and swapfile.
#
# Creates @swap subvolume if missing, mounts it, creates swapfile with
# optimal size, and updates fstab entries.
#
# Globals:
#   LAST_ERROR - Set on failure
#   temp_mount - Temporary root mount cleaned up by the setup transaction
# Returns:
#   0 on success, 1 on failure
create_btrfs_swap() {
  local btrfs_root
  local uuid
  local swap_size swap_subvolumes swap_subvol_id identity contents inode
  local mount_entry swap_entry entry entry_status mount_status
  local swap_mounted=false

  LAST_ERROR=""

  if ! btrfs_root=$(get_btrfs_root_device); then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to get btrfs root device: $error_msg"
    return 1
  fi

  if ! uuid=$(lsblk -dnro UUID "$btrfs_root" 2>/dev/null) || [[ -z "$uuid" || "$uuid" = *[[:space:]]* ]]; then
    LAST_ERROR="Failed to get a single UUID of btrfs root device: $btrfs_root"
    return 1
  fi
  uuid="${uuid,,}"
  if ! identity=$(findmnt -rn -o FSTYPE,UUID --mountpoint / 2>/dev/null) || [[ "$identity" != "btrfs $uuid" ]]; then
    LAST_ERROR="Cannot verify the btrfs root filesystem identity; check findmnt and lsblk"
    return 1
  fi
  if ! swap_subvolumes=$(sudo btrfs subvolume list / 2>/dev/null); then
    LAST_ERROR="Failed to list btrfs subvolumes; refusing to assume $SWAP_SUBVOL is missing"
    return 1
  fi
  swap_subvol_id=$(awk -v name="$SWAP_SUBVOL" '$1 == "ID" && $7 == 5 && $8 == "path" && $9 == name && NF == 9 {print $2}' <<<"$swap_subvolumes")
  if [[ -n "$swap_subvol_id" && ! "$swap_subvol_id" =~ ^[0-9]+$ ]]; then
    LAST_ERROR="Cannot identify a unique top-level $SWAP_SUBVOL subvolume"
    return 1
  fi

  if [[ -L "$SWAP_MOUNT_POINT" || (-e "$SWAP_MOUNT_POINT" && ! -d "$SWAP_MOUNT_POINT") ]]; then
    LAST_ERROR="$SWAP_MOUNT_POINT must be a non-symlink directory"
    return 1
  fi
  if [[ -d "$SWAP_MOUNT_POINT" ]]; then
    mount_status=0
    mountpoint -q "$SWAP_MOUNT_POINT" || mount_status="$?"
    case "$mount_status" in
    0)
      swap_mounted=true
      if [[ -z "$swap_subvol_id" ]]; then
        LAST_ERROR="$SWAP_MOUNT_POINT is mounted but the root filesystem has no top-level $SWAP_SUBVOL subvolume"
        return 1
      fi
      _validate_hibernation_swap_mount "$uuid" || return 1
      ;;
    32)
      # Btrfs subvolume roots use inode 256, even when not separate mounts.
      if ! inode=$(stat -c %i -- "$SWAP_MOUNT_POINT") || [[ "$inode" = 256 ]] ||
        ! contents=$(sudo find "$SWAP_MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit) || [[ -n "$contents" ]]; then
        LAST_ERROR="Unmounted $SWAP_MOUNT_POINT must be an empty ordinary directory; move conflicting contents or subvolumes before retrying"
        return 1
      fi
      ;;
    *)
      LAST_ERROR="Cannot determine whether $SWAP_MOUNT_POINT is mounted; check mountpoint before retrying"
      return 1
      ;;
    esac
  fi

  mount_entry="UUID=$uuid $SWAP_MOUNT_POINT btrfs defaults,noatime,nodatacow,subvol=$SWAP_SUBVOL 0 0"
  swap_entry="$SWAP_FILE_PATH none swap defaults 0 0"
  # Check both entries before mounting, creating, activating, or appending anything.
  for entry in "$mount_entry" "$swap_entry"; do
    entry_status=0
    _check_hibernation_fstab_entry "$entry" || entry_status="$?"
    [[ "$entry_status" = 0 || "$entry_status" = 2 ]] || return 1
  done

  if [[ -z "$swap_subvol_id" ]]; then
    if ! temp_mount="$(mktemp -d)"; then
      LAST_ERROR="Failed to create temporary root mount directory"
      return 1
    fi

    if ! sudo mount -o subvolid=5 "$btrfs_root" "$temp_mount" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs top-level subvolume"
      return 1
    fi

    if ! identity=$(findmnt -rn -o TARGET,FSTYPE,UUID,FSROOT --mountpoint "$temp_mount" 2>/dev/null) ||
      [[ "$identity" != "$temp_mount btrfs $uuid /" ]]; then
      LAST_ERROR="Cannot verify the temporary btrfs top-level mount; refusing to create $SWAP_SUBVOL"
      return 1
    fi
    if [[ -e "$temp_mount/$SWAP_SUBVOL" || -L "$temp_mount/$SWAP_SUBVOL" ]]; then
      LAST_ERROR="Top-level $SWAP_SUBVOL path already exists but was not identified as a subvolume; inspect it before retrying"
      return 1
    fi

    if ! sudo btrfs subvolume create "$temp_mount/$SWAP_SUBVOL" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swap subvolume"
      return 1
    fi
  fi

  if [[ "$swap_mounted" != true ]]; then
    if ! sudo mkdir -p "$SWAP_MOUNT_POINT" 2>/dev/null; then
      LAST_ERROR="Failed to create swap mount point directory"
      return 1
    fi

    if ! sudo mount -o subvol="$SWAP_SUBVOL" "$btrfs_root" "$SWAP_MOUNT_POINT" >/dev/null 2>&1; then
      LAST_ERROR="Failed to mount btrfs swap subvolume"
      return 1
    fi
  fi

  _validate_hibernation_swap_mount "$uuid" || return 1

  if [[ -f "$SWAP_FILE_PATH" ]]; then
    inode=$(stat -c %i -- "$SWAP_FILE_PATH") || return 1
    # Paths and fstab conventions cannot prove ownership of a legacy file.
    if [[ ! -r "$HIBERNATION_SWAP_OWNER" || "$(cat -- "$HIBERNATION_SWAP_OWNER")" != "$uuid $SWAP_FILE_PATH $inode" ]]; then
      log INFO "Existing swapfile has no matching ownership record; configure hibernation manually (left untouched)"
      return 3
    fi
  fi

  # Create swapfile if it doesn't exist
  if [[ ! -f "$SWAP_FILE_PATH" ]]; then
    swap_size=$(calculate_swap_size)

    if ! sudo btrfs filesystem mkswapfile --size "$swap_size" --uuid clear "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to create btrfs swapfile"
      return 1
    fi

    inode=$(stat -c %i -- "$SWAP_FILE_PATH") || return 1
    if ! (umask 077; mkdir -p -- "${HIBERNATION_SWAP_OWNER%/*}" && printf '%s\n' "$uuid $SWAP_FILE_PATH $inode" > "$HIBERNATION_SWAP_OWNER"); then
      LAST_ERROR="Failed to record managed swapfile ownership for retries"
      return 1
    fi

    log INFO "Created btrfs swapfile ($swap_size)"
  fi

  _validate_hibernation_swap_mount "$uuid" || return 1

  local offset
  if ! offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH" 2>/dev/null) || [[ ! "$offset" =~ ^[0-9]+$ ]]; then
    LAST_ERROR="Invalid Btrfs swapfile; map-swapfile validation failed for $SWAP_FILE_PATH"
    return 1
  fi

  # Activate swapfile if not already active
  local active_swap
  if ! active_swap=$(swapon --show=NAME --noheadings --raw 2>/dev/null); then
    LAST_ERROR="Failed to inspect active swap; refusing to activate an unverified swapfile"
    return 1
  fi
  if ! grep -qxF -- "$SWAP_FILE_PATH" <<<"$active_swap"; then
    if ! sudo swapon "$SWAP_FILE_PATH" >/dev/null 2>&1; then
      LAST_ERROR="Failed to activate swapfile"
      return 1
    fi
  fi

  if ! _add_hibernation_fstab_entry "$mount_entry" "swap subvolume mount"; then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to add swap subvolume to fstab: $error_msg"
    return 1
  fi

  if ! _add_hibernation_fstab_entry "$swap_entry" "swapfile"; then
    local error_msg="$LAST_ERROR"
    LAST_ERROR="Failed to add swapfile to fstab: $error_msg"
    return 1
  fi

  log INFO "Ensured swapfile entry in /etc/fstab"

  return 0
}

# Return 2 for retryable prerequisites, 3 for permanently unsupported/manual
# configurations, and 1 for failure. No boot configuration is published until
# the actual managed swapfile and all resume metadata have been verified.
setup_hibernation() {
  local resume_uuid luks_uuid cmdline resume_offset expected_uuid expected_luks status=0 token
  local -a hibernation_params tokens
  LAST_ERROR="Cannot inspect existing swap configuration; no swap or resume settings were changed"
  check_hibernation_swap_policy || return "$?"
  inspect_btrfs_device / || {
    log INFO "$LAST_ERROR"
    return 3
  }
  expected_uuid="$resume_uuid"
  expected_luks="$luks_uuid"
  if ! cmdline=$(get_limine_cmdline hibernation); then
    LAST_ERROR="Cannot verify persistent kernel arguments; review Limine defaults before retrying"
    return 2
  fi
  read -r -a tokens <<<"$cmdline"
  for token in "${tokens[@]}"; do
    case "$token" in
    resume=* | resume_offset=* | noresume | hibernate=no)
      log INFO "Existing external resume policy; configure hibernation manually (left untouched)"
      return 3 ;;
    esac
  done
  create_btrfs_swap || status="$?"
  if [[ "$status" != 0 ]]; then
    [[ "$status" = 3 ]] && return 3
    log WARN "Failed to prepare Btrfs swapfile: $LAST_ERROR"
    return 2
  fi
  inspect_btrfs_device "$SWAP_FILE_PATH" || return 1
  if [[ "$resume_uuid" != "$expected_uuid" || "$luks_uuid" != "$expected_luks" ]]; then
    LAST_ERROR="Swapfile device changed during setup; refusing to publish resume parameters"
    return 1
  fi
  if ! resume_offset=$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_FILE_PATH" 2>/dev/null) || [[ ! "$resume_offset" =~ ^[0-9]+$ ]]; then
    LAST_ERROR="Failed to get a valid Btrfs swapfile resume offset"
    return 1
  fi
  hibernation_params=("hibernate.compressor=lz4" "resume=UUID=$resume_uuid" "resume_offset=$resume_offset")

  ensure_limine_cmdline_defaults || return 1
  if ! update_limine_cmdline "50-hibernation.conf" --append "${hibernation_params[@]}"; then
    LAST_ERROR="Failed to write Limine hibernation config: $LAST_ERROR"
    return 1
  fi
  log INFO "Configured managed Btrfs swapfile resume"
}
