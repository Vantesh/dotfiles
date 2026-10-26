#!/usr/bin/env bash
# snapboot.sh - Shared bootloader and filesystem configuration helpers
#
# Provides Limine configuration and boot partition detection, command line
# updates, managed mkinitcpio drop-ins, deferred initramfs rebuild requests,
# and Btrfs device inspection used by boot setup scripts.
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
#   0 if root is btrfs, 1 if not, 2 if inspection fails, 127 if findmnt missing
check_btrfs() {
  LAST_ERROR=""

  if ! command_exists findmnt; then
    LAST_ERROR="findmnt command not found"
    return 127
  fi

  local filesystem
  if ! filesystem=$(findmnt -n -o FSTYPE / 2>/dev/null); then
    LAST_ERROR="Failed to detect root filesystem type"
    return 2
  fi

  if [[ "$filesystem" != btrfs ]]; then
    LAST_ERROR="Root filesystem is not btrfs"
    return 1
  fi

  return 0
}

# Update the append-only quiet-boot or hibernation fragment through the shared
# transaction. Preserve unrelated directives and refuse independent boot policy.
# Arguments: full feature filename, kernel parameters.
update_limine_cmdline() {
  local dropin_name="${1:-}" params fragment
  LAST_ERROR=""
  case "$dropin_name" in
  20-quiet-boot.conf | 50-hibernation.conf) ;;
  *)
    LAST_ERROR="Expected 20-quiet-boot.conf or 50-hibernation.conf"
    return 2
    ;;
  esac
  shift
  params="$*"
  if [[ -z "$params" ]]; then
    LAST_ERROR="update_limine_cmdline() requires kernel parameters"
    return 2
  fi
  fragment="/etc/limine-entry-tool.d/$dropin_name"
  sudo mkdir -p -- /etc/limine-entry-tool.d || return 1
  if ! edit_system_configs _stage_limine_fragment : "$fragment"; then
    LAST_ERROR="Failed to update $fragment; existing configuration was preserved; see diagnostics"
    return 1
  fi
}

_stage_limine_fragment() {
  get_limine_cmdline fragment-file "$dropin_name" "$1" "$params" >/dev/null || return 1
  if ! sudo cmp -s -- "$fragment" "$1"; then
    request_initramfs_rebuild || return 1
  fi
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

# Never initialize persistent defaults from a possibly temporary running boot.
# Respect explicit package/drop-in defaults, otherwise use the persistent kernel
# command line. Missing intent requires an operator decision, not a denylist.
ensure_limine_cmdline_defaults() {
  local status=0 params initial_defaults=""
  LAST_ERROR=""
  sudo bash -s <<'BASH' || status="$?"
set -euo pipefail
shopt -s nullglob
for file in /usr/share/limine-entry-tool.d/*.conf /etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf /etc/default/limine; do
  [[ -f "$file" ]] || continue
  operator='\+?='
  case "$file" in
    /etc/limine-entry-tool.d/01-default.conf|/etc/limine-entry-tool.d/20-quiet-boot.conf|/etc/limine-entry-tool.d/50-hibernation.conf|/etc/limine-entry-tool.d/zswap.conf)
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
  0)
    sudo test -f /etc/limine-entry-tool.d/01-default.conf || return 0 ;;
  2)
    if ! params=$(sudo cat -- /etc/kernel/cmdline) || [[ -z "${params//[[:space:]]/}" || "$params" == *$'\n'* ]]; then
      LAST_ERROR="No single-line persistent kernel command line found; review required boot arguments and set /etc/kernel/cmdline or KERNEL_CMDLINE[default] before retrying (never copy rescue/debug arguments blindly)"
      return 1
    fi
    printf -v initial_defaults 'KERNEL_CMDLINE[default]= "%s"\n' "${params//\"/\\\"}" ;;
  *) LAST_ERROR="Cannot read persistent Limine defaults; refusing to replace them"; return 1 ;;
  esac
  sudo mkdir -p -- /etc/limine-entry-tool.d || return 1
  if ! edit_system_configs _stage_limine_defaults : /etc/limine-entry-tool.d/01-default.conf; then
    LAST_ERROR="Failed to stage Limine defaults; existing configuration was preserved; see diagnostics"
    return 1
  fi
}

_stage_limine_defaults() {
  if [[ -n "$initial_defaults" ]]; then
    { printf '%s' "$initial_defaults"; cat -- "$1"; } > "$1.initialized" || return 1
    mv -f -- "$1.initialized" "$1" || return 1
  fi
  get_limine_cmdline deduplicate-file "$1" >/dev/null || return 1
  if ! sudo cmp -s -- /etc/limine-entry-tool.d/01-default.conf "$1"; then
    request_initramfs_rebuild || return 1
  fi
}

# Checks that Limine's UKI options do not disable managed mkinitcpio drop-ins.
#
# Explicit -c/--config arguments disable drop-ins even for the default config.
# Requires sudo access; callers validate before changing boot or swap settings.
# Globals:
#   LAST_ERROR - Set on unreadable configuration or unsupported options
# Returns:
#   0 on compatible options, 1 on read failure, 2 on unsupported options
validate_mkinitcpio_dropins() {
  LAST_ERROR=""

  local options
  if ! options="$(get_limine_config_value MKINITCPIO_UKI_OPTIONS)"; then
    LAST_ERROR="Failed to read effective Limine mkinitcpio UKI options"
    return 1
  fi

  local -a args=()
  read -r -a args <<<"$options"
  local arg value_pending=false
  # mkinitcpio accepts abbreviated long options and aliases. Only permit exact
  # presentation/compression options, never an unverified config/cmdline/build path.
  for arg in "${args[@]}"; do
    if [[ "$value_pending" = true ]]; then
      if [[ "$arg" = -* ]]; then
        LAST_ERROR="MKINITCPIO_UKI_OPTIONS is missing a value before $arg"
        return 2
      fi
      value_pending=false
      continue
    fi
    case "$arg" in
    --verbose | --quiet | --nocolor | -v | -q | -n) ;;
    --compress | --splash) value_pending=true ;;
    --compress=?* | --splash=?*) ;;
    *)
      LAST_ERROR="Review unsupported MKINITCPIO_UKI_OPTIONS argument ($arg); only exact verbosity, color, compression and splash options are allowed with managed hooks/unlocking/signing"
      return 2 ;;
    esac
  done
  if [[ "$value_pending" = true ]]; then
    LAST_ERROR="MKINITCPIO_UKI_OPTIONS is missing an option value"
    return 2
  fi
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

# Read literal persistent default arguments using Limine's config precedence.
# Never infer future unlocking from the currently running /proc/cmdline.
# initramfs accepts a verified LUKS UUID to defer simple cryptdevice validation.
# convert-unlock takes verified LUKS UUID, mapper, filesystem UUID, backing-device
# MAJ:MIN, and optional private kernel/default stage paths; empty paths preflight.
get_limine_cmdline() {
  # Retained boot consumers share the parser until their Phase 6C migration.
  sudo python3 -I -B "${CHEZMOI_SOURCE_DIR:?Chezmoi source directory required}/.chezmoitemplates/lib/limine_cmdline.py" "${1:?Limine operation required}" "${@:2}"
}

# Match mkinitcpio's concatenation and version sort, including a prospective
# replacement of our hook owner. Existing trusted root-owned configs still run.
# Arguments: current/base/candidate/unlock-check, prospective base content.
get_mkinitcpio_hooks() {
  sudo bash -s -- "${1:-current}" "${2:-}" <<'BASH'
set -euo pipefail
shopt -s nullglob
managed=/etc/mkinitcpio.conf.d/00-chezmoi-systemd.conf
files=(/etc/mkinitcpio.conf.d/*.conf "$managed")
mapfile -d '' -t files < <(printf '%s\0' "${files[@]}" | LC_ALL=C.UTF-8 sort -zVu)
config=$(
  cat -- /etc/mkinitcpio.conf || exit 1
  for file in "${files[@]}"; do
    if [[ "$file" = "$managed" ]]; then
      case "$1" in
      base) break ;;
      candidate) printf '%s\n' "$2"; continue ;;
      esac
    fi
    [[ -f "$file" ]] || continue
    [[ -r "$file" ]] || exit 1
    cat -- "$file" || exit 1
  done
)
source /dev/stdin <<<"$config"
if [[ "${HOOKS@a}" != *a* ]]; then read -r -a HOOKS <<< "${HOOKS:-}"; fi
if [[ "$1" = unlock-check ]]; then
  if [[ -e /crypto_keyfile.bin || " ${FILES[*]-} " = *crypto_keyfile.bin* ]]; then
    printf '%s\n' 'Implicit crypto_keyfile.bin requires user-managed systemd keyfile configuration' >&2
    exit 1
  fi
  for hook in "${HOOKS[@]}"; do
    [[ "$hook" != encrypt ]] || continue
    for file in /etc/initcpio/{install,hooks}/"$hook" /usr/lib/initcpio/{install,hooks}/"$hook"; do
      [[ -f "$file" ]] || continue
      [[ -r "$file" ]] || exit 1
      if grep -Eiq 'crypto_keyfile[.]bin|cryptkey' "$file"; then
        printf 'Keyfile hook %s requires user-managed systemd authentication\n' "$hook" >&2
        exit 1
      fi
    done
  done
fi
printf '%s\n' "${HOOKS[*]}"
BASH
}

# Verify a single Btrfs device and its ancestry, not its name. Called first for
# root (before mutations), then for the actual swapfile (before publication).
# Sets caller-local resume_uuid (filesystem UUID), luks_uuid, luks_device_id
# (backing-device MAJ:MIN) and root_mapping through Bash dynamic scope.
inspect_btrfs_device() {
  local target="$1" identity mount_point source filesystem uuid extra device metadata device_id block_fs block_uuid devices path types parent parent_id status kind backing resolved
  local -a parents
  LAST_ERROR="Unable to read unambiguous mount metadata for $target"
  identity=$(findmnt --nofsroot -rn -o TARGET,SOURCE,FSTYPE,UUID --target "$target" 2>/dev/null) || return 3
  read -r mount_point source filesystem uuid extra <<<"$identity"
  [[ "$mount_point" = /* && -n "$source" && -z "$extra" && "$identity" != *$'\n'* ]] || return 3
  LAST_ERROR="Filesystem at $target is not Btrfs"
  [[ "$filesystem" = btrfs ]] || return 3
  LAST_ERROR="Invalid Btrfs filesystem UUID metadata for $target"
  [[ "$uuid" =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$ ]] || return 3
  mount_point=$(printf '%b' "$mount_point")
  source=$(printf '%b' "$source")
  LAST_ERROR="Unable to resolve Btrfs backing device for $target"
  device=$(readlink -e -- "$source") || return 3
  metadata=$(lsblk -dnro FSTYPE,UUID,MAJ:MIN "$device" 2>/dev/null) || return 3
  read -r block_fs block_uuid device_id extra <<<"$metadata"
  LAST_ERROR="Filesystem UUID does not match the resolved device for $target"
  [[ "$block_fs" = btrfs && "$block_uuid" = "$uuid" ]] || return 3
  LAST_ERROR="Unable to identify the backing block device for $target"
  [[ "$device_id" =~ ^[0-9]+:[0-9]+$ && -z "$extra" && "$metadata" != *$'\n'* ]] || return 3
  # Use block-device identities, not Btrfs's anonymous filesystem device number.
  LAST_ERROR="Filesystem UUID resolves to a different or missing block device for $target"
  resolved=$(readlink -e -- "/dev/disk/by-uuid/$uuid") || return 3
  [[ $(lsblk -dnro MAJ:MIN "$resolved" 2>/dev/null) = "$device_id" ]] || return 3
  LAST_ERROR="Unable to inspect Btrfs device membership for $target"
  devices=$(sudo btrfs filesystem show --raw "$mount_point" 2>/dev/null) || return 3
  LAST_ERROR="Btrfs filesystem must report exactly one device for $target"
  [[ $(awk '/Total devices/ {print $3}' <<<"$devices") = 1 ]] || return 3
  LAST_ERROR="Btrfs member does not match the resolved backing block device for $target"
  path=$(awk '$1 == "devid" && $7 == "path" {match($0, /[[:space:]]path[[:space:]]+/); print substr($0, RSTART + RLENGTH)}' <<<"$devices")
  [[ -n "$path" && "$path" != *$'\n'* ]] || return 3
  resolved=$(readlink -e -- "$path") || return 3
  [[ $(lsblk -dnro MAJ:MIN "$resolved" 2>/dev/null) = "$device_id" ]] || return 3
  LAST_ERROR="Unsupported block-device topology for $target"
  types=$(lsblk -srn -o TYPE "$device" 2>/dev/null) || return 3
  luks_uuid=""
  luks_device_id=""
  root_mapping=""
  case "$types" in
  disk | $'part\ndisk') ;;
  $'crypt\npart\ndisk' | $'crypt\ndisk')
    LAST_ERROR="Unsupported device-mapper topology for $target: expected one direct backing device"
    parents=(/sys/dev/block/"$device_id"/slaves/*)
    [[ "${#parents[@]}" = 1 && -d "${parents[0]}" ]] || return 3
    IFS= read -r parent_id < "${parents[0]}/dev" || return 3
    [[ "$parent_id" =~ ^[0-9]+:[0-9]+$ && "$parent_id" != "$device_id" ]] || return 3
    parent=$(readlink -e -- "/dev/block/$parent_id") || return 3
    [[ $(lsblk -dnro MAJ:MIN "$parent" 2>/dev/null) = "$parent_id" ]] || return 3
    LAST_ERROR="LUKS backing device could not be verified for $target"
    kind=$(sudo blkid -p -s TYPE -o value "$parent" 2>/dev/null) || return 3
    [[ "$kind" = crypto_LUKS ]] || return 3
    status=$(sudo env LC_ALL=C cryptsetup status "$device" 2>/dev/null) || return 3
    kind=$(awk '$1 == "type:" {print $2}' <<<"$status")
    backing=$(awk '$1 == "device:" {sub(/^[[:space:]]*device:[[:space:]]*/, ""); print}' <<<"$status")
    [[ "$kind" = LUKS1 || "$kind" = LUKS2 ]] || return 3
    resolved=$(readlink -e -- "$backing") || return 3
    [[ $(lsblk -dnro MAJ:MIN "$resolved" 2>/dev/null) = "$parent_id" ]] || return 3
    luks_uuid=$(sudo blkid -p -s UUID -o value "$parent" 2>/dev/null) || return 3
    [[ "$luks_uuid" =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$ && "$luks_uuid" != "$uuid" ]] || return 3
    LAST_ERROR="Unable to verify active LUKS mapping identity for $target"
    IFS= read -r root_mapping < "/sys/dev/block/$device_id/dm/name" || return 3
    [[ -n "$root_mapping" ]] || return 3
    resolved=$(readlink -e -- "/dev/mapper/$root_mapping") || return 3
    [[ $(lsblk -dnro MAJ:MIN "$resolved" 2>/dev/null) = "$device_id" ]] || return 3
    luks_device_id="$parent_id"
    ;;
  *) return 3 ;;
  esac
  resume_uuid="$uuid"
  LAST_ERROR=""
}

# Check presence and reject root reformat/non-LUKS modes, not authentication policy.
verify_systemd_unlock() {
  local cmdline="$1" token options quotes quoted=false escaped=false status=0 selected=false named=false restricted=false disabled=false selectors=" "
  local -a tokens
  read -r -a tokens <<<"$cmdline"
  for token in "${tokens[@]}"; do
    case "$token" in
    *\"* | *\'* | *\\*) escaped=true ;;
    *) escaped=false ;;
    esac
    if [[ "$token" =~ (cryptdevice|cryptkey|crypto|luks)[.=] && ("$quoted" = true || "$escaped" = true) ]]; then
      LAST_ERROR="Quoted or escaped encryption arguments require manual reconciliation"
      return 1
    fi
    quotes="${token//[^\"]/}"
    if (( ${#quotes} % 2 )); then
      if [[ "$quoted" = false ]]; then quoted=true; else quoted=false; fi
    fi
    token="${token#rd.}"
    case "$token" in
    luks=0 | luks=no | luks=false | luks=off) return 1 ;;
    luks.crypttab=0 | luks.crypttab=no | luks.crypttab=false | luks.crypttab=off) disabled=true ;;
    luks.options=*)
      options="${token#*=}"
      if [[ "$options" =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}= ]]; then
        [[ "$options" = "$luks_uuid="* ]] || continue
        options="${options#*=}"
      fi
      case ",$options," in
      *,noauto,* | *,swap,* | *,tmp,* | *,tmp=* | *,plain,* | *,tcrypt* | *,bitlk,* | *,fvault2,*) return 1 ;;
      esac
      ;;
    luks.uuid=* | luks.name=*)
      [[ "$selectors" != *" $token "* ]] || return 1
      selectors+="$token "
      restricted=true
      case "$token" in
      "luks.uuid=$luks_uuid" | "luks.uuid=luks-$luks_uuid") selected=true ;;
      "luks.name=$luks_uuid=$root_mapping") selected=true; named=true ;;
      "luks.name=$luks_uuid="* | "luks.name="*"=$root_mapping") return 1 ;;
      esac
      ;;
    esac
  done
  [[ "$quoted" = false && ("$restricted" != true || "$selected" = true) ]] || return 1
  if [[ "$disabled" != true ]]; then
    sudo bash -s -- "$luks_uuid" "$root_mapping" <<'BASH' || status="$?"
set -euo pipefail
file=/etc/crypttab
if [[ -f /etc/crypttab.initramfs ]]; then file=/etc/crypttab.initramfs; fi
[[ -e "$file" ]] || exit 2
[[ -r "$file" ]] || exit 1
awk -v uuid="$1" -v mapping="$2" '
  !/^[[:space:]]*(#|$)/ &&
  (FILENAME ~ /crypttab.initramfs$/ || $4 ~ /(^|,)x-initrd.attach(,|$)/) &&
  ($1 == mapping || $2 == "UUID=" uuid || $2 == "/dev/disk/by-uuid/" uuid) {
    entries++
    if ($1 == mapping && ($2 == "UUID=" uuid || $2 == "/dev/disk/by-uuid/" uuid) &&
        $4 !~ /(^|,)(noauto|swap|tmp(=[^,]*)?|plain|tcrypt[^,]*|bitlk|fvault2)(,|$)/) matched++
  }
  END { exit (!entries ? 2 : entries != 1 || matched != 1) }
' "$file"
BASH
    case "$status" in
    0) return 0 ;;
    2) ;;
    *) return 1 ;;
    esac
  fi
  [[ "$named" = true || ("$selected" = true && "$root_mapping" = "luks-$luks_uuid") ]]
}

mkinitcpio_hook_exists() {
  [[ -f "/etc/initcpio/install/$1" || -f "/usr/lib/initcpio/install/$1" ]]
}

# One base HOOKS owner, before Snapper's independent snapshot-hook append.
# Validate the complete prospective configuration before the atomic write.
configure_systemd_initramfs() {
  # inspect_btrfs_device also populates the filesystem UUID through dynamic scope.
  # shellcheck disable=SC2034
  local resume_uuid luks_uuid luks_device_id root_mapping cmdline current effective ordered hook content phase=before seen=" " snapshot_required=false
  local convert=false kernel_present=false default_present=false
  local obsolete_hooks=" udev encrypt keymap consolefont resume btrfs-overlayfs "
  local -a hooks previous final_hooks middle=() tail=()
  validate_mkinitcpio_dropins || return 1
  inspect_btrfs_device / || return 1
  cmdline=$(get_limine_cmdline initramfs "$luks_uuid") || {
    LAST_ERROR="Cannot read persistent boot arguments; hooks were not changed"
    return 1
  }
  if [[ "$cmdline" =~ (^|[[:space:]\"])cryptdevice= ]]; then
    convert=true
    if ! cmdline=$(get_limine_cmdline convert-unlock "$luks_uuid" "$root_mapping" "$resume_uuid" "$luks_device_id" "" "") ||
      ! get_mkinitcpio_hooks unlock-check >/dev/null; then
      LAST_ERROR="Cannot safely convert installer unlocking; see the persistent source/keyfile diagnostics; configuration was not changed"
      return 1
    fi
    if sudo test -f /etc/kernel/cmdline && ! sudo test -L /etc/kernel/cmdline; then kernel_present=true; fi
    if sudo test -f /etc/limine-entry-tool.d/01-default.conf && ! sudo test -L /etc/limine-entry-tool.d/01-default.conf; then default_present=true; fi
  fi
  if [[ -n "$luks_uuid" ]] && ! verify_systemd_unlock "$cmdline"; then
    LAST_ERROR="No usable user-managed systemd early-unlock definition for '$root_mapping'. Configure rd.luks.name=$luks_uuid=$root_mapping or a matching included crypttab entry with x-initrd.attach; review disabled, non-LUKS or root-formatting options. TPM2 and credentials remain user-managed; hooks were not changed"
    return 1
  fi
  current=$(get_mkinitcpio_hooks base) || {
    LAST_ERROR="Cannot read base mkinitcpio configuration; hooks were not changed"
    return 1
  }
  read -r -a previous <<<"$current"
  if [[ " $current " = *' btrfs-overlayfs '* || " $current " = *' sd-btrfs-overlayfs '* ]]; then
    snapshot_required=true
  fi
  hooks=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block)
  [[ " $current " != *' plymouth '* ]] || hooks+=(plymouth)
  [[ -z "$luks_uuid" ]] || hooks+=(sd-encrypt)
  # Retain additional hardware/filesystem hooks in their existing relative order.
  for hook in "${previous[@]}"; do
    [[ "$obsolete_hooks" != *" $hook "* ]] || continue
    case "$hook" in
    filesystems) phase=filesystems; continue ;;
    fsck) phase=fsck; continue ;;
    shutdown) hook=sd-shutdown ;;
    esac
    [[ " ${hooks[*]} ${middle[*]} ${tail[*]} " != *" $hook "* ]] || continue
    [[ "$hook" != sd-encrypt || -n "$luks_uuid" ]] || continue
    case "$phase" in
    before) hooks+=("$hook") ;;
    filesystems) middle+=("$hook") ;;
    fsck) tail+=("$hook") ;;
    esac
  done
  hooks+=(filesystems "${middle[@]}" fsck "${tail[@]}")

  printf -v content '# Managed systemd base; snapshot hooks belong to Snapper.\nHOOKS=(%s)' "${hooks[*]}"
  local managed="$MKINITCPIO_DROPIN_DIR/00-chezmoi-systemd.conf" existing
  local managed_pattern='^# Managed systemd base; snapshot hooks belong to Snapper\.'$'\n''HOOKS=\([[:alnum:]_ -]+\)$'
  if sudo test -e "$managed" || sudo test -L "$managed"; then
    if sudo test -L "$managed" || ! existing=$(sudo cat -- "$managed") || [[ ! "$existing" =~ $managed_pattern ]]; then
      LAST_ERROR="Preserved $managed: unrecognized or independent configuration; review its contents manually before retrying"
      return 1
    fi
  fi
  # The probe exists only during preflight. Even a matching later assignment
  # would otherwise hide Snapper's current or future contribution.
  effective=$(get_mkinitcpio_hooks candidate "$content"$'\n''HOOKS+=(__chezmoi_base_owner__)') || {
    LAST_ERROR="Cannot evaluate prospective mkinitcpio configuration; hooks were not changed"
    return 1
  }
  if [[ " $effective " != *' __chezmoi_base_owner__ '* ]]; then
    LAST_ERROR="A later drop-in replaces the base HOOKS array; preserve append-only feature configuration before retrying"
    return 1
  fi
  # Validate the exact candidate too: the probe can change last-hook conditionals.
  effective=$(get_mkinitcpio_hooks candidate "$content") || {
    LAST_ERROR="Cannot evaluate the exact mkinitcpio configuration; hooks were not changed"
    return 1
  }
  if [[ "$snapshot_required" = true && " $effective " != *' sd-btrfs-overlayfs '* ]]; then
    LAST_ERROR="Existing snapshot boot would lose its overlay; configure Snapper's independent systemd selector before retrying"
    return 1
  fi
  ordered="$effective"
  if [[ " ${hooks[*]} " != *' sd-btrfs-overlayfs '* ]]; then
    ordered="${ordered/ sd-btrfs-overlayfs/}"
  fi
  if [[ "$ordered" != "${hooks[*]}" && "$ordered" != "${hooks[*]} "* ]]; then
    LAST_ERROR="Later configuration changes the managed systemd hooks; review it before retrying"
    return 1
  fi
  read -r -a final_hooks <<<"$effective"
  for hook in "${final_hooks[@]}"; do
    if [[ "$obsolete_hooks" = *" $hook "* || "$seen" = *" $hook "* ]] ||
      [[ "$hook" = sd-encrypt && -z "$luks_uuid" ]] ||
      [[ ! "$hook" =~ ^[[:alnum:]_-]+$ ]] || ! mkinitcpio_hook_exists "$hook"; then
      LAST_ERROR="Unavailable, duplicate or incompatible mkinitcpio hook: $hook; hooks were not changed"
      return 1
    fi
    seen+="$hook "
  done
  if [[ "$convert" != true ]]; then
    write_mkinitcpio_dropin 00-chezmoi-systemd.conf "$content"
    return
  fi
  local -a targets=()
  [[ "$kernel_present" != true ]] || targets+=(/etc/kernel/cmdline)
  [[ "$default_present" != true ]] || targets+=(/etc/limine-entry-tool.d/01-default.conf)
  targets+=("$managed")
  sudo mkdir -p -- "$MKINITCPIO_DROPIN_DIR" || return 1
  if ! edit_system_configs _stage_initramfs_unlock _verify_initramfs_unlock "${targets[@]}"; then
    LAST_ERROR="Installer unlock conversion failed; configuration was preserved or rolled back; any rebuild request remains pending"
    return 1
  fi
}

# Reuse the shared transaction for arguments and hooks; all validation precedes
# publication, and the post-check reads the actual persistent configuration.
_stage_initramfs_unlock() {
  local kernel_stage="" default_stage="" candidate
  if [[ "$kernel_present" = true ]]; then kernel_stage="$1"; shift; fi
  if [[ "$default_present" = true ]]; then default_stage="$1"; shift; fi
  candidate=$(get_limine_cmdline convert-unlock "$luks_uuid" "$root_mapping" "$resume_uuid" "$luks_device_id" "$kernel_stage" "$default_stage") || return 1
  [[ "$candidate" = "$cmdline" ]] && verify_systemd_unlock "$candidate" || return 1
  [[ $(get_mkinitcpio_hooks candidate "$content") = "$effective" ]] || return 1
  printf '%s\n' "$content" > "$1" || return 1
  request_initramfs_rebuild
}

_verify_initramfs_unlock() {
  local actual
  actual=$(get_limine_cmdline initramfs) && [[ "$actual" = "$cmdline" ]] &&
    verify_systemd_unlock "$actual" && [[ $(get_mkinitcpio_hooks) = "$effective" ]]
}
