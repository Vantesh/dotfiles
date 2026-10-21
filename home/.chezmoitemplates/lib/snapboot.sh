#!/usr/bin/env bash
# snapboot.sh - Shared bootloader and filesystem configuration helpers
#
# Provides Limine configuration and boot partition detection, command line
# updates, managed mkinitcpio drop-ins, deferred initramfs rebuild requests,
# and btrfs/fstab operations used by setup scripts.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   INITRAMFS_PENDING_FILE - Persistent rebuild request shared between scripts
#   MKINITCPIO_DROPIN_DIR - Directory for managed initramfs configuration
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

readonly INITRAMFS_PENDING_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/initramfs.pending"
readonly MKINITCPIO_DROPIN_DIR="/etc/mkinitcpio.conf.d"

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

# Updates Limine kernel command line via drop-in file.
#
# Creates configuration file in /etc/limine-entry-tool.d/ with
# KERNEL_CMDLINE[default] directive. Use --append for += operator.
# Escapes quotes in parameters and atomically replaces root-owned drop-ins.
# Requests a deferred rebuild before changed writes; unchanged content is skipped.
#
# Arguments:
#   $1 - Drop-in filename (e.g., "50-hibernation" or "50-hibernation.conf")
#   --append - Optional flag to use += operator instead of = (must be $2 if present)
#   $@ - Kernel parameters to add (from $2 or $3 onwards)
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args
update_limine_cmdline() {
  local dropin_name="${1:-}"

  LAST_ERROR=""

  if [[ -z "$dropin_name" ]]; then
    LAST_ERROR="update_limine_cmdline() requires drop-in filename as first argument"
    return 2
  fi

  shift

  local operator="="
  if [[ "${1:-}" == "--append" ]]; then
    operator="+="
    shift
  fi

  local params="$*"

  if [[ -z "$params" ]]; then
    LAST_ERROR="update_limine_cmdline() requires kernel parameters"
    return 2
  fi

  [[ "$dropin_name" != *.conf ]] && dropin_name+=".conf"

  if [[ ! "$dropin_name" =~ ^[[:alnum:]_-]+\.conf$ ]]; then
    LAST_ERROR="Limine drop-in filename must not contain directory components"
    return 2
  fi

  local dropin_dir="/etc/limine-entry-tool.d"
  local dropin_file="$dropin_dir/$dropin_name"

  local escaped_params
  if ! escaped_params="$(printf '%s' "$params" | sed 's/"/\\"/g')"; then
    LAST_ERROR="Failed to escape Limine kernel parameters"
    return 1
  fi

  local content
  printf -v content 'KERNEL_CMDLINE[default]%s "%s"' "$operator" "$escaped_params"

  if printf '%s\n' "$content" | sudo cmp -s -- "$dropin_file" -; then
    return 0
  fi

  if ! request_initramfs_rebuild; then
    return 1
  fi

  if ! sudo mkdir -p "$dropin_dir" 2>/dev/null; then
    LAST_ERROR="Failed to create Limine drop-in directory: $dropin_dir"
    return 1
  fi

  local stage=""
  if ! (
    stage="$(sudo mktemp -- "$dropin_dir/.$dropin_name.XXXXXX")" || exit 1
    trap 'sudo rm -f -- "$stage" >/dev/null 2>&1 || true' EXIT
    trap 'exit 1' INT TERM
    printf '%s\n' "$content" | sudo tee "$stage" >/dev/null 2>&1 || exit 1
    sudo chmod 0644 "$stage" >/dev/null 2>&1 || exit 1
    sudo chown root:root "$stage" >/dev/null 2>&1 || exit 1
    sudo mv -f -- "$stage" "$dropin_file" >/dev/null 2>&1 || exit 1
  ) >/dev/null 2>&1; then
    LAST_ERROR="Failed to atomically write Limine drop-in file: $dropin_file"
    return 1
  fi

  return 0
}

# Reads a Limine option using package configuration precedence, without execution.
# Arguments:
#   $1 - Uppercase configuration key
# Globals:
#   LAST_ERROR - Set on invalid key or configuration read failure
# Outputs:
#   Effective value to stdout, empty when absent
# Returns:
#   0 on success, 1 on read failure, 2 on invalid key
get_limine_config_value() {
  local key="${1:-}"
  LAST_ERROR=""

  if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    LAST_ERROR="get_limine_config_value() requires an uppercase configuration key"
    return 2
  fi

  if ! sudo bash -s -- "$key" <<'BASH'
set -euo pipefail
shopt -s nullglob
files=()
for file in /usr/share/limine-entry-tool.d/*.conf /etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf /etc/default/limine; do
  [[ -f "$file" ]] || continue
  if [[ "$1" = "ENABLE_ENROLL_LIMINE_CONFIG" && "$file" != "/etc/default/limine" ]]; then
    continue
  fi
  files+=("$file")
done
if [[ "${#files[@]}" -eq 0 ]]; then
  exit 0
fi
awk -v key="$1" '
  $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
    value = $0
    sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", value)
    sub(/"$/, "", value)
    sub(/^"/, "", value)
  }
  END { print value }
' "${files[@]}"
BASH
  then
    LAST_ERROR="Failed to read effective Limine configuration: $key"
    return 1
  fi

  return 0
}

# Finds Limine's mounted FAT32 boot partition using package search precedence.
#
# Honors the effective ESP_PATH setting and otherwise checks the same mount
# locations as Limine. Requires sudo access for reading configuration.
# Globals:
#   LAST_ERROR - Set on invalid configuration or a missing FAT32 mount
# Outputs:
#   Boot partition mount path to stdout
# Returns:
#   0 on success, 1 on detection failure, 127 if findmnt is missing
get_limine_boot_directory() {
  LAST_ERROR=""

  if ! command_exists findmnt; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  local configured_path
  if ! configured_path="$(get_limine_config_value ESP_PATH)"; then
    LAST_ERROR="Failed to read Limine ESP_PATH"
    return 1
  fi

  local -a paths=(/efi /boot /boot/efi /limine)
  if [[ -n "$configured_path" ]]; then
    if [[ "$configured_path" != /* ]]; then
      LAST_ERROR="Limine ESP_PATH must be an absolute mount path"
      return 1
    fi
    paths=("${configured_path%/}")
  fi

  local path filesystem
  for path in "${paths[@]}"; do
    if filesystem="$(findmnt -rn -o FSTYPE --mountpoint "$path" 2>/dev/null)" && [[ "$filesystem" = "vfat" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done

  LAST_ERROR="Limine FAT32 boot partition not mounted; mount it or configure ESP_PATH in /etc/default/limine"
  return 1
}

# Only ESP-root limine.conf is managed. Ignore alternate configs on public
# machines; personal machines remove only the known legacy EFI configs.
validate_limine_config_location() {
  local directory="$1" candidate
  LAST_ERROR=""
  [[ "${PERSONAL:-0}" == "1" ]] || return 0

  for candidate in EFI/BOOT/limine.conf EFI/limine/limine.conf EFI/limine.conf; do
    if ! sudo rm -f -- "$directory/$candidate"; then
      LAST_ERROR="Failed to remove legacy Limine config: $directory/$candidate"
      return 1
    fi
  done
  return 0
}

# Never initialize persistent defaults from a possibly temporary running boot.
# Respect explicit package/drop-in defaults, otherwise use the persistent kernel
# command line. Missing intent requires an operator decision, not a denylist.
ensure_limine_cmdline_defaults() {
  local status=0 params
  LAST_ERROR=""
  sudo bash -s <<'BASH' || status="$?"
set -euo pipefail
shopt -s nullglob
for file in /usr/share/limine-entry-tool.d/*.conf /etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf /etc/default/limine; do
  [[ -f "$file" ]] || continue
  operator='\+?='
  case "$file" in
    /etc/limine-entry-tool.d/01-default.conf|/etc/limine-entry-tool.d/20-quiet-boot.conf|/etc/limine-entry-tool.d/50-hibernation.conf)
      # Managed += fragments add features, not a persistent boot baseline.
      operator='=' ;;
  esac
  if grep -Eq "^[[:space:]]*KERNEL_CMDLINE\[default\][[:space:]]*$operator" "$file"; then
    exit 0
  else
    status=$?
    [[ "$status" = 1 ]] || exit 1
  fi
done
exit 2
BASH
  case "$status" in
  0) return 0 ;;
  2) ;;
  *) LAST_ERROR="Cannot read persistent Limine defaults; refusing to replace them"; return 1 ;;
  esac
  if ! params=$(sudo cat -- /etc/kernel/cmdline) || [[ -z "${params//[[:space:]]/}" || "$params" == *$'\n'* ]]; then
    LAST_ERROR="No single-line persistent kernel command line found; review required boot arguments and set /etc/kernel/cmdline or KERNEL_CMDLINE[default] before retrying (never copy rescue/debug arguments blindly)"
    return 1
  fi
  update_limine_cmdline "01-default.conf" "$params"
}

# Checks that Limine's UKI options do not disable managed mkinitcpio drop-ins.
#
# Explicit -c/--config arguments disable drop-ins even for the default config.
# Requires sudo access; callers validate before changing boot or swap settings.
# Globals:
#   LAST_ERROR - Set on unreadable configuration or unsupported options
# Returns:
#   0 on compatible options, 1 on read failure, 2 on explicit config selection
validate_mkinitcpio_dropins() {
  LAST_ERROR=""

  local options
  if ! options="$(get_limine_config_value MKINITCPIO_UKI_OPTIONS)"; then
    LAST_ERROR="Failed to read effective Limine mkinitcpio UKI options"
    return 1
  fi

  local -a args=()
  read -r -a args <<<"$options"
  local arg short_options
  for arg in "${args[@]}"; do
    case "$arg" in
    --config | --config=*)
      LAST_ERROR="MKINITCPIO_UKI_OPTIONS selects an explicit config ($arg), which disables /etc/mkinitcpio.conf.d; remove -c/--config before managed hook setup"
      return 2
      ;;
    --) break ;;
    --*) continue ;;
    -*)
      short_options="${arg:1}"
      while [[ -n "$short_options" ]]; do
        case "${short_options:0:1}" in
        c)
          LAST_ERROR="MKINITCPIO_UKI_OPTIONS selects an explicit config ($arg), which disables /etc/mkinitcpio.conf.d; remove -c/--config before managed hook setup"
          return 2
          ;;
        A | g | H | h | k | p | r | S | s | t | U) break ;;
        esac
        short_options="${short_options:1}"
      done
      ;;
    esac
  done

  return 0
}

# Writes a managed mkinitcpio drop-in without modifying the main configuration.
#
# Validates shell syntax and skips identical content. Queues a rebuild before
# staging a root-owned file in the destination directory and replacing it atomically.
# Temporary files are cleaned up on failure or interruption.
#
# Arguments:
#   $1 - Drop-in filename ending in .conf, without directory components
#   $2 - Shell configuration content
# Globals:
#   MKINITCPIO_DROPIN_DIR - Destination directory
#   LAST_ERROR - Set on validation, request, or write failure
# Returns:
#   0 on success or unchanged content, 1 on failure, 2 on invalid arguments
write_mkinitcpio_dropin() {
  local name="${1:-}"
  local content="${2:-}"

  LAST_ERROR=""

  if [[ ! "$name" =~ ^[[:alnum:]_-]+\.conf$ ]] || [[ -z "$content" ]]; then
    LAST_ERROR="write_mkinitcpio_dropin() requires a .conf filename and content"
    return 2
  fi

  if ! bash -n <<<"$content" >/dev/null 2>&1; then
    LAST_ERROR="Invalid shell syntax in mkinitcpio drop-in: $name"
    return 2
  fi

  local destination="$MKINITCPIO_DROPIN_DIR/$name"
  if printf '%s\n' "$content" | sudo cmp -s -- "$destination" -; then
    return 0
  fi

  if ! request_initramfs_rebuild; then
    return 1
  fi

  if ! sudo mkdir -p -- "$MKINITCPIO_DROPIN_DIR" >/dev/null 2>&1; then
    LAST_ERROR="Failed to create mkinitcpio drop-in directory: $MKINITCPIO_DROPIN_DIR"
    return 1
  fi

  local stage=""
  if ! (
    stage="$(sudo mktemp -- "$MKINITCPIO_DROPIN_DIR/.$name.XXXXXX")" || exit 1
    trap 'sudo rm -f -- "$stage" >/dev/null 2>&1 || true' EXIT
    trap 'exit 1' INT TERM
    printf '%s\n' "$content" | sudo tee "$stage" >/dev/null 2>&1 || exit 1
    sudo chmod 0644 "$stage" >/dev/null 2>&1 || exit 1
    sudo chown root:root "$stage" >/dev/null 2>&1 || exit 1
    sudo mv -f -- "$stage" "$destination" >/dev/null 2>&1 || exit 1
  ) >/dev/null 2>&1; then
    LAST_ERROR="Failed to write mkinitcpio drop-in: $destination"
    return 1
  fi

  return 0
}

# Requests one late initramfs rebuild before a boot-related configuration write.
#
# The marker survives failed or interrupted applies. The late rebuild script runs
# on every apply and removes it after rebuild and optional config enrollment succeed.
#
# Globals:
#   INITRAMFS_PENDING_FILE - Marker shared between setup scripts
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 if the persistent request cannot be written
request_initramfs_rebuild() {
  LAST_ERROR=""

  if ! (
    umask 077
    mkdir -p -- "${INITRAMFS_PENDING_FILE%/*}" && touch -- "$INITRAMFS_PENDING_FILE"
  ) >/dev/null 2>&1; then
    LAST_ERROR="Failed to request initramfs rebuild: $INITRAMFS_PENDING_FILE"
    return 1
  fi

  return 0
}
