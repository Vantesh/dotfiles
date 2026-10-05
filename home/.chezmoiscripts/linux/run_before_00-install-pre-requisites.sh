#!/usr/bin/env bash
# 00-install-pre-requisites.sh - Install prerequisites for setup and templates
#
# Installs git, figlet, and base-devel for all setups. Personal setups also configure
# Bitwarden and log in before secret-backed templates render. Secret reads
# unlock the vault on demand; desktop packages are installed by later scripts.
# Globals:
#   PERSONAL - Enable vault prerequisites only when set to 1
#   CHEZMOI_SOURCE_DIR - Source directory containing shared libraries

# Exit codes: 0 (success), 1 (failure), 127 (missing pacman)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoitemplates/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/common.sh"

# Reads and validates the vault email without placing diagnostics on stdout.
# Outputs: Email to stdout, prompts and errors to stderr.
# Returns: 0 on success, 1 if no email can be read.
get_bitwarden_email() {
  local email

  while true; do
    printf '%b%s%b ' "$COLOR_CYAN" "Enter your Bitwarden email:" "$COLOR_RESET" >&2

    if [[ -t 0 ]]; then
      if ! read -r email; then
        log ERROR "Failed to read Bitwarden email from standard input"
        return 1
      fi
    elif [[ -r /dev/tty ]]; then
      if ! read -r email </dev/tty; then
        log ERROR "Failed to read Bitwarden email from terminal"
        return 1
      fi
    else
      log ERROR "No interactive terminal available to read Bitwarden email"
      return 1
    fi

    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      printf '%s\n' "$email"
      return 0
    fi

    log WARN "Invalid email format, try again"
  done
}

main() {
  local -a packages=(git figlet base-devel)
  local -a missing_packages=()
  local package email output

  if ! command_exists pacman; then
    die 127 "Unsupported distribution: pacman not found"
  fi

  if [[ "${PERSONAL:-0}" = "1" ]]; then
    packages+=(rbw pinentry)
  fi

  for package in "${packages[@]}"; do
    if ! pacman -Q "$package" >/dev/null 2>&1; then
      missing_packages+=("$package")
    fi
  done

  if [[ "${#missing_packages[@]}" -gt 0 ]]; then
    log STEP "Installing prerequisites: ${missing_packages[*]}"
    if ! sudo pacman -S --needed --noconfirm "${missing_packages[@]}"; then
      die "Failed to install prerequisites: ${missing_packages[*]}"
    fi
    log INFO "Installed prerequisites"
  fi

  if [[ "${PERSONAL:-0}" != "1" ]]; then
    return 0
  fi

  print_box "Bitwarden"
  log STEP "Bitwarden Setup"

  if rbw login >/dev/null 2>&1; then
    log SKIP "Bitwarden already logged in"
  else
    log INFO "Logging in to Bitwarden"

    if ! email="$(get_bitwarden_email)"; then
      die "Failed to read Bitwarden email"
    fi

    if ! output="$(rbw config set email "$email" 2>&1)"; then
      die "Failed to set rbw email: ${output:-no output}"
    fi

    if ! rbw login; then
      die "Failed to login to Bitwarden"
    fi

    log INFO "Logged in to Bitwarden"
  fi

  if ! output="$(rbw config set lock_timeout 10800)"; then
    log WARN "Failed to set rbw lock_timeout: ${output:-no output}"
  fi
}

main "$@"
