#!/usr/bin/env bash
# 09_setup_dms.sh - Setup DankMaterialShell for Quickshell
#
# Clones DankMaterialShell repository, customizes matugen-worker.sh,
# removes unnecessary scripts, and patches theme.qml for proper error color handling.
#
# Exit codes:
#   0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly DMS_REPO="https://github.com/AvengeMedia/DankMaterialShell.git"
readonly DMS_DIR="$HOME/.config/quickshell/dms"
readonly SCRIPTS_DIR="$DMS_DIR/scripts"
readonly MATUGEN_WORKER="$SCRIPTS_DIR/matugen-worker.sh"
readonly THEME_QML="$DMS_DIR/Common/Theme.qml"

# Hash to trigger re-run when this script changes
# hash: {{ include ".chezmoiscripts/linux/run_onchange_after_setup_dms.sh" | sha256sum }}

clone_dms() {
  if [[ -d "$DMS_DIR" ]]; then
    log SKIP "DankMaterialShell already cloned"
    return 0
  fi

  if ! mkdir -p "$HOME/.config/quickshell" 2>/dev/null; then
    log ERROR "Failed to create quickshell config directory"
    return 1
  fi

  log INFO "Cloning DankMaterialShell (this may take a moment)"
  if ! git clone --depth 1 "$DMS_REPO" "$DMS_DIR" >/dev/null 2>&1; then
    log ERROR "Failed to clone DankMaterialShell repository"
    return 1
  fi

  log INFO "Cloned DankMaterialShell"
  return 0
}

replace_matugen_worker() {
  if [[ ! -d "$SCRIPTS_DIR" ]]; then
    log ERROR "Scripts directory not found: $SCRIPTS_DIR"
    return 1
  fi

  cat >"$MATUGEN_WORKER" <<'EOF'
#!/usr/bin/env bash
# matugen-worker - Process matugen color scheme requests
#
# Reads desired color scheme from STATE_DIR/matugen.desired.json and executes
# walset with appropriate arguments. Supports both image and hex color inputs
# with optional mode (dark/light) and scheme selection.
#
# Arguments:
#   $1 - STATE_DIR: Directory containing matugen.desired.json
#   $2 - SHELL_DIR: Shell configuration directory (unused)
#   $3 - CONFIG_DIR: Configuration directory (unused)
#   $4 - Must be "--run" (safety flag)
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid config), 127 (command not found)

set -euo pipefail

shopt -s nullglob globstar

die() {
  local exit_code=1
  local msg

  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi

  msg="$*"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send "matugen-worker" "$msg" -i error -u critical
  fi

  printf 'matugen-worker: %s\n' "$msg" >&2
  exit "$exit_code"
}

validate_arguments() {
  if [[ $# -lt 4 ]]; then
    die 1 "Usage: $0 STATE_DIR SHELL_DIR CONFIG_DIR --run"
  fi

  readonly STATE_DIR="$1"
  readonly SHELL_DIR="$2"
  readonly CONFIG_DIR="$3"

  if [[ ! -d "$STATE_DIR" ]]; then
    die 1 "STATE_DIR '$STATE_DIR' does not exist"
  fi

  if [[ ! -d "$SHELL_DIR" ]]; then
    die 1 "SHELL_DIR '$SHELL_DIR' does not exist"
  fi

  if [[ ! -d "$CONFIG_DIR" ]]; then
    die 1 "CONFIG_DIR '$CONFIG_DIR' does not exist"
  fi

  shift 3

  if [[ "${1:-}" != "--run" ]]; then
    die 1 "Fourth argument must be '--run'"
  fi
}

read_config() {
  local desired_json="$STATE_DIR/matugen.desired.json"

  if [[ ! -f "$desired_json" ]]; then
    exit 2
  fi

  local mode kind value scheme
  read -r mode kind value scheme < <(
    jq -r '[.mode // empty, .kind // empty, .value // empty, .matugenType // empty] | @tsv' "$desired_json"
  )

  if [[ -z "$kind" || -z "$value" ]]; then
    exit 2
  fi

  if [[ "$kind" != "image" && "$kind" != "hex" ]]; then
    exit 2
  fi

  if [[ -n "$mode" && "$mode" != "dark" && "$mode" != "light" ]]; then
    exit 2
  fi

  printf '%s\n%s\n%s\n%s\n' "$mode" "$kind" "$value" "$scheme"
}

build_walset_args() {
  local mode="$1"
  local kind="$2"
  local value="$3"
  local scheme="$4"
  local -a args=()

  case "$kind" in
  image)
    if [[ ! -r "$value" ]]; then
      exit 2
    fi
    args=("image" "$value")
    ;;
  hex)
    args=("color" "$value")
    ;;
  *)
    exit 2
    ;;
  esac

  if [[ -n "$scheme" ]]; then
    args+=("--scheme" "$scheme")
  fi

  if [[ "$mode" == "dark" || "$mode" == "light" ]]; then
    args+=("--mode" "$mode")
  fi

  printf '%s\0' "${args[@]}"
}

main() {
  validate_arguments "$@"

  if ! command -v walset >/dev/null 2>&1; then
    die 127 "walset not found. Ensure ~/.local/bin is in PATH"
  fi

  local mode kind value scheme
  {
    read -r mode
    read -r kind
    read -r value
    read -r scheme
  } < <(read_config)

  local -a args=()
  while read -rd '' arg; do
    args+=("$arg")
  done < <(build_walset_args "$mode" "$kind" "$value" "$scheme")

  exec walset "${args[@]}"
}

main "$@"
EOF

  if ! chmod +x "$MATUGEN_WORKER" 2>/dev/null; then
    log ERROR "Failed to make matugen-worker.sh executable"
    return 1
  fi

  log INFO "Replaced matugen-worker.sh"
  return 0
}

remove_unnecessary_scripts() {
  local files_to_remove=(
    "$SCRIPTS_DIR/qt.sh"
    "$SCRIPTS_DIR/gtk.sh"
  )

  local removed=0
  for file in "${files_to_remove[@]}"; do
    if [[ -f "$file" ]]; then
      if ! rm -f "$file" 2>/dev/null; then
        log WARN "Failed to remove: $(basename "$file")"
      else
        removed=$((removed + 1))
      fi
    fi
  done

  if [[ $removed -gt 0 ]]; then
    log INFO "Removed theming scripts"
  fi

  return 0
}

patch_theme_qml() {
  if [[ ! -f "$THEME_QML" ]]; then
    log ERROR "Theme file not found: $THEME_QML"
    return 1
  fi

  if grep -q 'getMatugenColor("error"' "$THEME_QML" 2>/dev/null; then
    return 0
  fi

  if ! sed -i 's/"error": "#F2B8B5",/"error": getMatugenColor("error", "#F2B8B5"),/' "$THEME_QML" 2>/dev/null; then
    log ERROR "Failed to patch theme.qml"
    return 1
  fi

  log INFO "Patched theme.qml"
  return 0
}

main() {
  log STEP "DankMaterialShell"

  if ! clone_dms; then
    die "Failed to clone DankMaterialShell repository"
  fi

  if ! replace_matugen_worker; then
    die "Failed to replace matugen-worker.sh"
  fi

  remove_unnecessary_scripts

  if ! patch_theme_qml; then
    die "Failed to patch theme.qml"
  fi
}

main "$@"
