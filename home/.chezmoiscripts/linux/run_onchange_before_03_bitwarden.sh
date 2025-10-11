#!/usr/bin/env bash
# 03_bitwarden.sh - Install and configure Bitwarden
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

if [[ "${PERSONAL:-0}" != "1" ]]; then
  exit 0
fi

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-package_manager.sh"

install_bitwarden_packages() {
  local -a packages=(
    rbw
  )

  case "${DISTRO_FAMILY,,}" in
  *arch*)
    packages+=(bitwarden-bin)
    ;;
  esac

  if ! install_package "${packages[@]}"; then
    log ERROR "Failed to install Bitwarden packages: $LAST_ERROR"
    return 1
  fi

  return 0
}

validate_email() {
  local email="${1:-}"

  if [[ -z "$email" ]]; then
    return 1
  fi

  if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    return 0
  fi

  return 1
}

get_bitwarden_email() {
  local email

  LAST_ERROR=""

  while true; do
    printf '%b%s%b ' "$COLOR_CYAN" "Enter your Bitwarden email:" "$COLOR_RESET" >&2

    if [[ -t 0 ]]; then
      if ! read -r email; then
        email=""
      fi
    elif [[ -r /dev/tty ]]; then
      if ! read -r email </dev/tty; then
        email=""
      fi
    else
      LAST_ERROR="No interactive terminal available to read Bitwarden email"
      return 1
    fi

    if validate_email "$email"; then
      printf '%s' "$email"
      return 0
    fi

    log WARN "Invalid email format, try again"
  done
}

create_browser_manifest() {
  local target_dir="${1:-}"
  local manifest

  if [[ -z "$target_dir" ]]; then
    LAST_ERROR="create_browser_manifest() requires a directory argument"
    return 2
  fi

  manifest="$target_dir/com.8bit.bitwarden.json"

  if [[ -f "$manifest" ]]; then
    return 0
  fi

  if ! mkdir -p "$target_dir"; then
    LAST_ERROR="Failed to create directory: $target_dir"
    return 1
  fi

  if ! cat >"$manifest" <<'EOF'; then
{
  "name": "com.8bit.bitwarden",
  "description": "Bitwarden desktop <-> browser bridge",
  "path": "/usr/lib/bitwarden/desktop_proxy",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://nngceckbapebfimnlniiiahkandclblb/",
    "chrome-extension://hccnnhgbibccigepcmlgppchkpfdophk/",
    "chrome-extension://jbkfoedolllekgbhcbcoahefnbanhhlh/",
    "chrome-extension://ccnckbpmaceehanjmeomladnmlffdjgn/"
  ]
}
EOF
    LAST_ERROR="Failed to write manifest: $manifest"
    return 1
  fi

  log INFO "Created manifest: $manifest"
  return 0
}

setup_browser_integration() {
  local -a browser_dirs=(
    "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$HOME/.config/google-chrome/NativeMessagingHosts"
  )

  local dir
  for dir in "${browser_dirs[@]}"; do
    if ! create_browser_manifest "$dir"; then
      log WARN "Failed to create browser manifest in $dir: $LAST_ERROR"
    fi
  done
}

login_bitwarden() {
  local email

  if rbw login >/dev/null 2>&1; then
    log SKIP "Bitwarden already logged in"
    return 0
  fi

  log INFO "Logging in to Bitwarden"

  email=$(get_bitwarden_email)

  if ! rbw config set email "$email" >/dev/null 2>&1; then
    LAST_ERROR="Failed to set rbw email configuration"
    return 1
  fi

  if ! rbw login; then
    LAST_ERROR="Failed to login to Bitwarden"
    return 1
  fi

  log INFO "Logged in to Bitwarden"
  return 0
}

main() {
  print_box "Bitwarden"
  log STEP "Bitwarden Setup"

  if ! install_bitwarden_packages; then
    die "Failed to install Bitwarden packages"
  fi

  setup_browser_integration

  if ! login_bitwarden; then
    die "Failed to login to Bitwarden: $LAST_ERROR"
  fi

}

main "$@"
