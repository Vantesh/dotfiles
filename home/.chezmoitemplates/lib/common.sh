#!/usr/bin/env bash
# common.sh - Common utilities and logging functions
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

trap 'printf "%b" "$COLOR_RESET"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export NOCONFIRM="${NOCONFIRM:-0}"

# Outputs formatted log messages to stderr.
#
# Supports color-coded output for different log levels. STEP level adds
# a stage label. Respects NO_COLOR environment variable.
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
  STEP) color="$COLOR_BLUE" ;;
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

# Compose trusted cleanup functions without losing the previous EXIT status/trap.
_run_exit_cleanup() {
  local status="$1"
  "$2" || true
  return "$status"
}

add_exit_cleanup() {
  local callback="$1" saved body='' head
  [[ "$callback" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
  declare -F "$callback" >/dev/null || return 2
  saved=$(trap -p EXIT)
  if [[ -n "$saved" ]]; then
    # Decode only Bash's own quoted trap output, never caller-supplied shell text.
    eval "set -- ${saved#trap -- }"
    body="$1"
  fi
  head='if _run_exit_cleanup "$?" '"$callback"'; then'
  [[ "$body" == "$head"$'\n'* || "$body" == *$'\n'"$head"$'\n'* ]] && return 0
  # Expand the saved trap body now; its own runtime expansions stay literal.
  # shellcheck disable=SC2064
  trap "$head
${body:-:}
else
${body:-:}
fi" EXIT
}

keep_sudo_alive() {
  LAST_ERROR=""
  if ! sudo -v; then
    LAST_ERROR="Failed to obtain sudo access"
    return 1
  fi
  add_exit_cleanup _kill_sudo_keepalive || return
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$_SUDO_KEEPALIVE_PID" 2>/dev/null; then
    return 0
  fi
  _SUDO_KEEPALIVE_OWNER=$BASHPID
  (
    # Invoked by the worker EXIT trap.
    # shellcheck disable=SC2329
    _stop_keepalive_sleep() {
      local sleep_pid
      for sleep_pid in $(jobs -pr); do
        kill "$sleep_pid" 2>/dev/null || true
      done
      wait 2>/dev/null || true
    }
    trap _stop_keepalive_sleep EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    while true; do
      sleep 60 &
      wait "$!" || exit
      sudo -n true 2>/dev/null || exit
    done
  ) &
  _SUDO_KEEPALIVE_PID=$!
  return 0
}

_kill_sudo_keepalive() {
  [[ "${_SUDO_KEEPALIVE_OWNER:-$BASHPID}" == "$BASHPID" ]] || return 0
  if [[ -n "${_SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    wait "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset _SUDO_KEEPALIVE_PID _SUDO_KEEPALIVE_OWNER
  fi
}

# Edit private copies, atomically publish them, and undo only this invocation's
# published contents if editing/post-validation fails. Persistent .bak files are
# deliberately unrelated. Callbacks receive staged paths, not live system paths.
edit_system_configs() (
  local edit="$1" verify="$2"
  shift 2
  local -a targets=("$@") existed=() initial=() expected=() changed=() stages=() root_stages=()
  local work_dir='' rollback=true i path stage

  _config_state() {
    sudo stat -c '%d:%i:%f:%u:%g:%s:%y' -- "$1"
  }

  _config_matches() {
    local file="$1" stamp="$2" contents="$3" current
    current=$(_config_state "$file" 2>/dev/null) || return 1
    [[ "$current" == "$stamp" ]] && sudo cmp -s -- "$contents" "$file"
  }

  # Invoked by this operation subshell's EXIT trap.
  # shellcheck disable=SC2329
  _finish_config_edits() {
    local index target restore
    if [[ "$rollback" == true ]]; then
      for ((index=${#targets[@]}-1; index>=0; index--)); do
        [[ "${changed[index]:-false}" == true ]] || continue
        target="${targets[index]}"
        if [[ "${existed[index]}" == true ]] &&
          _config_matches "$target" "${initial[index]}" "$work_dir/$index.before"; then
          continue
        fi
        if ! _config_matches "$target" "${expected[index]}" "${stages[index]}"; then
          log ERROR "Skipped rollback of $target: it changed unexpectedly"
          continue
        fi
        if [[ "${existed[index]}" == true ]]; then
          restore=$(sudo mktemp -- "$target.rollback.XXXXXX") || continue
          if ! sudo cp -a -- "$work_dir/$index.before" "$restore" ||
            ! _config_matches "$target" "${expected[index]}" "${stages[index]}" ||
            ! sudo mv -Tf -- "$restore" "$target"; then
            log ERROR "Failed to restore this invocation's snapshot of $target"
            sudo rm -f -- "$restore" || true
            continue
          fi
        elif ! sudo rm -f -- "$target"; then
          log ERROR "Failed to remove this invocation's new file: $target"
          continue
        fi
        log INFO "Rolled back $target from this invocation"
      done
    fi
    for stage in "${root_stages[@]}"; do
      sudo rm -f -- "$stage" || true
    done
    [[ -z "$work_dir" ]] || rm -rf -- "$work_dir"
  }

  # This subshell owns only its snapshots, not the parent script's resources.
  trap _finish_config_edits EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  work_dir=$(mktemp -d) || exit 1
  for i in "${!targets[@]}"; do
    path="${targets[i]}"
    if sudo test -L "$path" || { sudo test -e "$path" && ! sudo test -f "$path"; }; then
      log ERROR "Refusing to edit non-regular configuration: $path"
      exit 1
    fi
    stages[i]="$work_dir/$i.next"
    existed[i]=false
    if sudo test -e "$path"; then
      existed[i]=true
      initial[i]=$(_config_state "$path") || exit 1
      sudo cp -a -- "$path" "$work_dir/$i.before" || exit 1
      # The snapshot may be root-only; the staged output must be user-owned.
      # shellcheck disable=SC2024
      sudo cat -- "$work_dir/$i.before" > "${stages[i]}" || exit 1
      _config_matches "$path" "${initial[i]}" "$work_dir/$i.before" || exit 1
    else
      : > "${stages[i]}"
    fi
  done
  if ! "$edit" "${stages[@]}"; then
    log ERROR "Failed to prepare configuration edits; live files were not changed"
    exit 1
  fi
  for i in "${!targets[@]}"; do
    path="${targets[i]}"
    if [[ "${existed[i]}" == true ]]; then
      _config_matches "$path" "${initial[i]}" "$work_dir/$i.before" || {
        log ERROR "$path changed before publication; refusing to overwrite it"
        exit 1
      }
      sudo cmp -s -- "$work_dir/$i.before" "${stages[i]}" && continue
    elif sudo test -e "$path" || sudo test -L "$path"; then
      log ERROR "$path was created by another actor; refusing to overwrite it"
      exit 1
    fi
    stage=$(sudo mktemp -- "$path.chezmoi.XXXXXX") || exit 1
    root_stages+=("$stage")
    sudo cp -- "${stages[i]}" "$stage" || exit 1
    if [[ "${existed[i]}" == true ]]; then
      sudo cp --attributes-only --preserve=all -- "$work_dir/$i.before" "$stage" || exit 1
      _config_matches "$path" "${initial[i]}" "$work_dir/$i.before" || exit 1
    else
      sudo chmod 644 -- "$stage" || exit 1
      if sudo test -e "$path" || sudo test -L "$path"; then exit 1; fi
    fi
    expected[i]=$(_config_state "$stage") || exit 1
    changed[i]=true
    sudo mv -Tf -- "$stage" "$path" || exit 1
  done
  if ! "$verify"; then
    log ERROR "Configuration post-check failed: ${LAST_ERROR:-see diagnostics}"
    exit 1
  fi
  rollback=false
)

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
