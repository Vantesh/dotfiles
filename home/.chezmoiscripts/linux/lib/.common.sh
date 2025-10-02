#!/usr/bin/env bash
# lib/common.sh - Common utility functions for system configuration scripts
#
# Contains both silent utilities (use LAST_ERROR/LAST_SUCCESS) and logging functions

export LAST_ERROR="${LAST_ERROR:-}"
export LAST_SUCCESS="${LAST_SUCCESS:-}"

# Respect NO_COLOR standard
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; then
  readonly COLOR_RESET=""
  readonly COLOR_INFO=""
  readonly COLOR_WARN=""
  readonly COLOR_ERROR=""
  readonly COLOR_STEP=""
  readonly COLOR_CYAN=""
else
  readonly COLOR_RESET="\033[0m"
  readonly COLOR_INFO="\033[1;32m"
  readonly COLOR_WARN="\033[1;33m"
  readonly COLOR_ERROR="\033[1;31m"
  readonly COLOR_STEP="\033[1;34m"
  readonly COLOR_CYAN="\033[1;36m"
fi

trap 'printf "%b" "$COLOR_RESET"' EXIT ERR INT TERM

# ==============================================================================================
# Logging Functions
# ==============================================================================================

log() {
  local level="${1:-}"
  shift || true
  local message="$*"

  if [[ -z "$level" ]] || [[ -z "$message" ]]; then
    printf '[ERROR] log() requires a level and a message\n' >&2
    return 1
  fi

  local color="$COLOR_RESET"
  case "${level^^}" in
  INFO) color="$COLOR_INFO" ;;
  WARN) color="$COLOR_WARN" ;;
  ERROR) color="$COLOR_ERROR" ;;
  STEP)
    printf '\n%b::%b %s\n\n' "$COLOR_STEP" "$COLOR_RESET" "$message" >&2
    return 0
    ;;
  *)
    printf '[ERROR] Invalid log level: %s\n' "$level" >&2
    return 1
    ;;
  esac

  printf '%b%s:%b %b\n' "$color" "${level^^}" "$COLOR_RESET" "$message" >&2
}

die() {
  local exit_code=1

  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi

  log ERROR "$@"
  exit "$exit_code"
}

print_box() {
  local text="${1:-}"
  local font="${2:-smslant}"

  figlet -t -f "$font" "$text"
}

# ==============================================================================================
# Utility Functions
# ==============================================================================================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

write_system_config() {
  local config_file="$1"
  local description="${2:-configuration}"

  LAST_ERROR=""
  LAST_SUCCESS=""

  if [[ -z "$config_file" ]]; then
    LAST_ERROR="write_system_config() requires config_file argument"
    return 2
  fi

  if [[ "$config_file" != /* ]]; then
    LAST_ERROR="config_file must be an absolute path: $config_file"
    return 2
  fi

  local parent_dir
  parent_dir="$(dirname "$config_file")"

  if ! sudo mkdir -p "$parent_dir"; then
    LAST_ERROR="Failed to create directory: $parent_dir"
    return 1
  fi

  # Write content from stdin to file atomically using tee
  if ! sudo tee "$config_file" >/dev/null; then
    LAST_ERROR="Failed to write to $config_file"
    return 1
  fi

  if ! sudo chmod 644 "$config_file"; then
    LAST_ERROR="Failed to set permissions (644) for $config_file"
    return 1
  fi

  LAST_SUCCESS="$description"
  return 0
}

create_backup() {
  local target_path="$1"
  local backup_path="${target_path}.bak"

  LAST_ERROR=""

  if [[ -z "$target_path" ]]; then
    LAST_ERROR="create_backup() requires target_path argument"
    return 2
  fi

  if [[ ! -e "$target_path" ]]; then
    LAST_ERROR="Target path does not exist: $target_path"
    return 2
  fi

  if [[ -e "$backup_path" ]]; then
    return 0
  fi

  # Determine if sudo is needed based on write permissions
  local backup_dir
  backup_dir="$(dirname "$backup_path")"

  local copy_cmd="cp"
  if [[ ! -w "$backup_dir" ]]; then
    copy_cmd="sudo cp"
  fi

  if ! $copy_cmd -a "$target_path" "$backup_path" 2>/dev/null; then
    LAST_ERROR="Failed to create backup: $target_path -> $backup_path"
    return 1
  fi

  return 0
}

# ==============================================================================================
# Configuration File Management
# ==============================================================================================

_is_system_path() {
  local path="$1"

  case "$path" in
  /etc/* | /usr/* | /opt/* | /var/*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

_run_with_optional_sudo() {
  local use_sudo="$1"
  shift

  if [[ "$use_sudo" == "true" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

_create_config_file() {
  local config_file="$1"
  local use_sudo="$2"

  if ! _run_with_optional_sudo "$use_sudo" touch "$config_file"; then
    LAST_ERROR="Failed to create file: $config_file"
    return 1
  fi

  if [[ "$use_sudo" == "true" ]]; then
    if ! sudo chown root:root "$config_file"; then
      LAST_ERROR="Failed to set ownership for: $config_file"
      return 1
    fi
  fi

  if ! _run_with_optional_sudo "$use_sudo" chmod 644 "$config_file"; then
    LAST_ERROR="Failed to set permissions for: $config_file"
    return 1
  fi

  return 0
}

_escape_regex_key() {
  local key="$1"
  # Escape regex special characters: [ ] \ . * ^ $
  printf '%s' "$key" | sed 's/[][\.*^$]/\\&/g'
}

_escape_replacement() {
  local text="$1"
  # Escape sed replacement special characters: & and \
  printf '%s' "$text" | sed 's/[&\\]/\\&/g'
}

_detect_spacing_style() {
  local config_file="$1"
  local use_sudo="$2"

  # Check for spaced style: key = value (spaces around =)
  if _run_with_optional_sudo "$use_sudo" grep -qE '^[[:space:]]*[^#;][^=[:space:]]+[[:space:]]+=[[:space:]]+' "$config_file" 2>/dev/null; then
    printf 'spaced'
  else
    printf 'compact'
  fi
}

_update_existing_key() {
  local config_file="$1"
  local escaped_key="$2"
  local key="$3"
  local value="$4"
  local use_sudo="$5"
  local style="$6"

  local delim='|'
  local key_regex="^[[:space:]]*#?[[:space:]]*${escaped_key}[[:space:]]*="

  local escaped_value
  escaped_value="$(_escape_replacement "$value")"

  local replacement
  if [[ "$style" == "spaced" ]]; then
    replacement="${key} = ${escaped_value}"
  else
    replacement="${key}=${escaped_value}"
  fi

  if ! _run_with_optional_sudo "$use_sudo" sed -i -E "s${delim}${key_regex}.*${delim}${replacement}${delim}" "$config_file"; then
    LAST_ERROR="Failed to update $key in $config_file"
    return 1
  fi

  return 0
}

_append_new_key() {
  local config_file="$1"
  local key="$2"
  local value="$3"
  local style="$4"
  local use_sudo="$5"

  local line
  if [[ "$style" == "spaced" ]]; then
    line="${key} = ${value}"
  else
    line="${key}=${value}"
  fi

  if [[ "$use_sudo" == "true" ]]; then
    if ! printf '\n%s\n' "$line" | sudo tee -a "$config_file" >/dev/null; then
      LAST_ERROR="Failed to append $key to $config_file"
      return 1
    fi
  else
    if ! printf '\n%s\n' "$line" >>"$config_file"; then
      LAST_ERROR="Failed to append $key to $config_file"
      return 1
    fi
  fi

  return 0
}

update_config() {
  local config_file="$1"
  local key="$2"
  local value="$3"

  LAST_ERROR=""

  if [[ -z "$config_file" ]] || [[ -z "$key" ]]; then
    LAST_ERROR="update_config() requires config_file and key arguments"
    return 2
  fi

  # Determine if this is a system config requiring sudo
  local use_sudo="false"
  if _is_system_path "$config_file"; then
    use_sudo="true"
  fi

  # Ensure parent directory exists
  local parent_dir
  parent_dir="$(dirname "$config_file")"

  if [[ ! -d "$parent_dir" ]]; then
    if ! _run_with_optional_sudo "$use_sudo" mkdir -p "$parent_dir"; then
      LAST_ERROR="Failed to create directory: $parent_dir"
      return 1
    fi
  fi

  # Create file if it doesn't exist
  if [[ ! -f "$config_file" ]]; then
    if ! _create_config_file "$config_file" "$use_sudo"; then
      return 1
    fi
  fi

  local escaped_key
  escaped_key="$(_escape_regex_key "$key")"

  local key_regex="^[[:space:]]*#?[[:space:]]*${escaped_key}[[:space:]]*="

  # Detect file's spacing style
  local style
  style="$(_detect_spacing_style "$config_file" "$use_sudo")"

  # Check if key exists and update or append accordingly
  if _run_with_optional_sudo "$use_sudo" grep -qE "$key_regex" "$config_file" 2>/dev/null; then
    if ! _update_existing_key "$config_file" "$escaped_key" "$key" "$value" "$use_sudo" "$style"; then
      return 1
    fi
  else
    if ! _append_new_key "$config_file" "$key" "$value" "$style" "$use_sudo"; then
      return 1
    fi
  fi

  return 0
}
