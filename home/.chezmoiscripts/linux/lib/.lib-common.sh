#!/usr/bin/env bash
# .lib-common.sh - Common utilities and logging functions
#
# Provides core utility functions for logging, user interaction, system
# configuration, and service management. This is the base library for all scripts.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   COLOR_* - Color codes for terminal output
# Exit codes:
#   Functions return 0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]] || [[ "${TERM:-}" == "dumb" ]]; then
  readonly COLOR_RESET=""
  readonly COLOR_GREEN=""
  readonly COLOR_YELLOW=""
  readonly COLOR_RED=""
  readonly COLOR_BLUE=""
  readonly COLOR_CYAN=""
  readonly COLOR_MAGENTA=""
else
  readonly COLOR_RESET="\033[0m"
  readonly COLOR_GREEN="\033[1;32m"
  readonly COLOR_YELLOW="\033[1;33m"
  readonly COLOR_RED="\033[1;31m"
  readonly COLOR_BLUE="\033[1;34m"
  readonly COLOR_CYAN="\033[1;36m"
  readonly COLOR_MAGENTA="\033[0;35m"
fi

trap 'printf "%b" "$COLOR_RESET"' EXIT ERR INT TERM

export NOCONFIRM="${NOCONFIRM:-0}"

# Outputs formatted log messages to stderr.
#
# Supports color-coded output for different log levels. STEP level adds
# visual spacing with blank lines. Respects NO_COLOR environment variable.
#
# Arguments:
#   $1 - Log level: INFO, WARN, ERROR, SKIP, or STEP
#   $@ - Message to log
# Outputs:
#   Formatted message to stderr
# Returns:
#   0 on success, 1 on invalid arguments
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
  INFO) color="$COLOR_GREEN" ;;
  WARN) color="$COLOR_YELLOW" ;;
  ERROR) color="$COLOR_RED" ;;
  SKIP) color="$COLOR_MAGENTA" ;;
  STEP)
    printf '\n%b::%b %s\n\n' "$COLOR_BLUE" "$COLOR_RESET" "$message" >&2
    return 0
    ;;
  *)
    printf '[ERROR] Invalid log level: %s\n' "$level" >&2
    return 1
    ;;
  esac

  printf '%b%s:%b %b\n' "$color" "${level^^}" "$COLOR_RESET" "$message" >&2
}

# Logs error message and exits with specified code.
#
# Arguments:
#   $1 - Optional exit code (default: 1)
#   $@ - Error message
# Outputs:
#   Error message to stderr via log()
# Returns:
#   Does not return (exits process)
die() {
  local exit_code=1

  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi

  log ERROR "$@"
  exit "$exit_code"
}

# Displays text in figlet banner.
#
# Arguments:
#   $1 - Text to display
#   $2 - Font name (default: smslant)
# Outputs:
#   ASCII art banner to stdout
print_box() {
  local text="${1:-}"
  local font="${2:-smslant}"

  figlet -f "$font" "$text"
}

# Prompts user for yes/no confirmation.
#
# Loops until valid input (y/yes/n/no) is received. Case-insensitive.
# Empty input uses the default value.
#
# Arguments:
#   $1 - Prompt text (default: "Continue?")
#   $2 - Default answer: 'y' or 'n' (default: 'y')
# Globals:
#   LAST_ERROR - Set on invalid default value
# Outputs:
#   Prompt to stderr, reads from stdin
# Returns:
#   0 for yes, 1 for no, 2 for invalid default
confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-y}"

  if [[ "${NOCONFIRM:-0}" == "1" ]]; then
    return 0
  fi

  local options

  case "${default,,}" in
  y | yes)
    options="[Y/n]"
    ;;
  n | no)
    options="[y/N]"
    ;;
  *)
    LAST_ERROR="default must be 'y' or 'n'"
    return 2
    ;;
  esac

  while true; do
    printf '\n%b%s%b %s ' "$COLOR_CYAN" "$prompt" "$COLOR_RESET" "$options" >&2

    if [[ -t 0 ]]; then
      if ! read -r response; then
        response=""
      fi
    elif [[ -r /dev/tty ]]; then
      if ! read -r response </dev/tty; then
        response=""
      fi
    else
      response="$default"
    fi

    response="${response,,}"

    if [[ -z "$response" ]]; then
      response="$default"
    fi

    case "$response" in
    y | yes)
      return 0
      ;;
    n | no)
      return 1
      ;;
    *)
      printf '%bInvalid input. Please enter y or n.%b\n' "$COLOR_YELLOW" "$COLOR_RESET" >&2
      ;;
    esac
  done
}

# Checks if a command is available in PATH.
#
# Arguments:
#   $1 - Command name
# Returns:
#   0 if command exists, 1 otherwise
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Gets the OS ID from /etc/os-release.
#
# Outputs:
#   OS ID to stdout (e.g., "arch", "fedora", "cachyos")
# Returns:
#   0 on success, 1 if os-release not found
get_os_id() {
  if [[ ! -f /etc/os-release ]]; then
    return 1
  fi

  # shellcheck source=/dev/null
  source /etc/os-release
  printf '%s\n' "${ID:-}"
  return 0
}

# Gets the OS NAME from /etc/os-release.
#
# Outputs:
#   OS NAME to stdout (e.g., "Arch Linux", "Fedora Linux")
# Returns:
#   0 on success, 1 if os-release not found
get_os_name() {
  if [[ ! -f /etc/os-release ]]; then
    return 1
  fi

  # shellcheck source=/dev/null
  source /etc/os-release
  printf '%s\n' "${NAME:-}"
  return 0
}

# Reloads and triggers udev rules.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure
reload_udev_rules() {
  LAST_ERROR=""

  if ! sudo udevadm control --reload-rules >/dev/null 2>&1; then
    LAST_ERROR="Failed to reload udev rules"
    return 1
  fi

  if ! sudo udevadm trigger >/dev/null 2>&1; then
    LAST_ERROR="Failed to trigger udev"
    return 1
  fi

  return 0
}

# Reloads systemd daemon configuration.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure
reload_systemd_daemon() {
  LAST_ERROR=""

  if ! sudo systemctl daemon-reload >/dev/null 2>&1; then
    LAST_ERROR="Failed to reload systemd daemon"
    return 1
  fi

  return 0
}

# Detects if system is a laptop.
#
# Uses hostnamectl to check chassis type for laptop/notebook.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 if laptop, 1 otherwise or on error
is_laptop() {
  local chassis

  LAST_ERROR=""

  if ! chassis=$(hostnamectl chassis 2>/dev/null); then
    LAST_ERROR="Failed to detect chassis type"
    return 1
  fi

  if [[ "$chassis" =~ (laptop|notebook) ]]; then
    return 0
  fi

  return 1
}

# Keeps sudo session alive in background.
#
# Starts background process that refreshes sudo every 60 seconds.
# Automatically killed on script exit via trap.
#
# Globals:
#   LAST_ERROR - Set on failure
#   _SUDO_KEEPALIVE_PID - Internal: background process PID
# Returns:
#   0 on success, 1 on failure

keep_sudo_alive() {
  LAST_ERROR=""

  if ! sudo -v; then
    LAST_ERROR="Failed to obtain sudo access"
    return 1
  fi

  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$_SUDO_KEEPALIVE_PID" 2>/dev/null; then
    return 0
  fi

  (
    while sleep 60; do
      sudo -n true 2>/dev/null || exit
    done
  ) &

  export _SUDO_KEEPALIVE_PID=$!

  trap '_kill_sudo_keepalive' EXIT INT TERM

  return 0
}

_kill_sudo_keepalive() {
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$_SUDO_KEEPALIVE_PID" 2>/dev/null; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset _SUDO_KEEPALIVE_PID
  fi
}

# Writes content to system config file with proper permissions.
#
# Creates parent directories if needed. Sets ownership to root:root and
# permissions to 644. Uses sudo for creation and writing.
# Arguments:
#   $1 - Config file path
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args
write_system_config() {
  local config_file="$1"

  LAST_ERROR=""

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

  if ! sudo tee "$config_file" >/dev/null; then
    LAST_ERROR="Failed to write to $config_file"
    return 1
  fi

  if ! sudo chmod 644 "$config_file"; then
    LAST_ERROR="Failed to set permissions (644) for $config_file"
    return 1
  fi

  return 0
}

# Creates .bak backup of file (idempotent).
#
# Only creates backup if .bak file doesn't already exist. Preserves
# first backup forever. Uses sudo if target directory not writable.
#
# Arguments:
#   $1 - Target file path
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success (created or already exists), 1 on failure, 2 on invalid args
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
  printf '%s' "$key" | sed 's/[][\.*^$]/\\&/g'
}

_escape_replacement() {
  local text="$1"
  printf '%s' "$text" | sed 's/[&\\]/\\&/g'
}

_detect_spacing_style() {
  local config_file="$1"
  local use_sudo="$2"

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

# Updates key=value in config file (auto-detects spacing style).
#
# Creates file if missing. Auto-detects 'key=value' vs 'key = value' style.
# Updates existing keys or appends new ones. Uses sudo for system paths.
#
# Arguments:
#   $1 - Config file path
#   $2 - Key name
#   $3 - Value
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args
update_config() {
  local config_file="$1"
  local key="$2"
  local value="$3"

  LAST_ERROR=""

  if [[ -z "$config_file" ]] || [[ -z "$key" ]]; then
    LAST_ERROR="update_config() requires config_file and key arguments"
    return 2
  fi

  local use_sudo="false"
  if _is_system_path "$config_file"; then
    use_sudo="true"
  fi

  local parent_dir
  parent_dir="$(dirname "$config_file")"

  if [[ ! -d "$parent_dir" ]]; then
    if ! _run_with_optional_sudo "$use_sudo" mkdir -p "$parent_dir"; then
      LAST_ERROR="Failed to create directory: $parent_dir"
      return 1
    fi
  fi

  if [[ ! -f "$config_file" ]]; then
    if ! _create_config_file "$config_file" "$use_sudo"; then
      return 1
    fi
  fi

  local escaped_key
  escaped_key="$(_escape_regex_key "$key")"

  local key_regex="^[[:space:]]*#?[[:space:]]*${escaped_key}[[:space:]]*="

  local style
  style="$(_detect_spacing_style "$config_file" "$use_sudo")"

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

# Enables systemd service/timer/socket.
# Arguments:
#   $1 - Unit name (e.g., 'ly', 'ly.service', 'docker.socket')
#   $2 - Scope: 'system' or 'user' (default: 'system')
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure, 2 on invalid args
enable_service() {
  local unit="${1:-}"
  local scope="${2:-system}"

  LAST_ERROR=""

  if [[ -z "$unit" ]]; then
    LAST_ERROR="enable_service() requires a unit argument"
    return 2
  fi

  if [[ "$scope" != "system" ]] && [[ "$scope" != "user" ]]; then
    LAST_ERROR="Invalid scope: $scope (must be 'system' or 'user')"
    return 2
  fi

  local use_sudo="true"
  local systemctl_args=()
  if [[ "$scope" = "user" ]]; then
    use_sudo="false"
    systemctl_args=("--user")
  fi

  local status_code=0
  _run_with_optional_sudo "$use_sudo" systemctl "${systemctl_args[@]}" is-enabled "$unit" >/dev/null 2>&1 || status_code=$?

  case "$status_code" in
  0 | 3)
    return 0
    ;;
  1)
    if _run_with_optional_sudo "$use_sudo" systemctl "${systemctl_args[@]}" enable "$unit" >/dev/null 2>&1; then
      return 0
    fi
    LAST_ERROR="Failed to enable $unit (scope: $scope)"
    return 1
    ;;
  4)
    LAST_ERROR="Unit not found: $unit"
    return 1
    ;;
  *)
    LAST_ERROR="Failed to query state of $unit (scope: $scope)"
    return 1
    ;;
  esac
}
