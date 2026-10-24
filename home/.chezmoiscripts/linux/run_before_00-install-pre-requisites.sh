#!/usr/bin/env bash
# 00-install-pre-requisites.sh - Install prerequisites for setup and templates
#
# Installs git, figlet, and base-devel and ensures mise for all setups.
# Personal setups configure Bitwarden in this prerequisite phase, not before
# target rendering. Secret reads unlock the vault on demand; desktop packages
# are installed by later scripts.
# Globals:
#   PERSONAL - Enable vault prerequisites only when set to 1
#   CHEZMOI_SOURCE_DIR - Source directory containing shared libraries

# Exit codes: 0 (success), 1 (failure)

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

  if [[ "$NOCONFIRM" == "1" || -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ||
        -n "${GITLAB_CI:-}" || -n "${CODESPACES:-}" ]] ||
    { [[ ! -t 0 ]] && ! (: </dev/tty) 2>/dev/null; }; then
    log ERROR "Configure Bitwarden first with 'rbw config set email YOUR_EMAIL', then rerun setup"
    return 1
  fi

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
  local package email output rbw_config rbw_config_file

  if ! command_exists mise; then
    packages+=(mise)
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

  if ! rbw_config="$(rbw config show 2>/dev/null)"; then
    # A fresh profile has no config file; other read failures must not reset it.
    rbw_config_file="${XDG_CONFIG_HOME:-$HOME/.config}/rbw${RBW_PROFILE:+-$RBW_PROFILE}/config.json"
    if [[ -e "$rbw_config_file" || -L "$rbw_config_file" ]]; then
      die "Failed to read Bitwarden configuration; inspect the error with 'rbw config show'"
    fi
    rbw_config=""
  fi

  if ! grep -qE '^[[:space:]]*"email":[[:space:]]*"[^"]+"' <<< "$rbw_config"; then
    print_box "Bitwarden"
    log STEP "Bitwarden Setup"

    if ! email="$(get_bitwarden_email)"; then
      die "Failed to read Bitwarden email"
    fi

    if ! output="$(rbw config set email "$email" 2>&1)"; then
      die "Failed to set rbw email: ${output:-no output}"
    fi
  fi

  if ! grep -qE '^[[:space:]]*"lock_timeout":[[:space:]]*10800,?[[:space:]]*$' <<< "$rbw_config"; then
    if ! output="$(rbw config set lock_timeout 10800)"; then
      log WARN "Failed to set rbw lock_timeout: ${output:-no output}"
    fi
  fi

  rbw login || die "$?" "Failed to login to Bitwarden"
}

main "$@"
