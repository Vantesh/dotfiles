#!/usr/bin/env bash

# Chezmoi bootstrap script

set -euo pipefail

readonly REPO="https://github.com/vantesh/dotfiles"

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]] || [[ "${TERM:-}" = "dumb" ]]; then
  readonly COLOR_RESET=""
  readonly COLOR_GREEN=""
  readonly COLOR_YELLOW=""
  readonly COLOR_RED=""
  readonly COLOR_BLUE=""
  readonly COLOR_CYAN=""
else
  readonly COLOR_RESET="\033[0m"
  readonly COLOR_GREEN="\033[1;32m"
  readonly COLOR_YELLOW="\033[1;33m"
  readonly COLOR_RED="\033[1;31m"
  readonly COLOR_BLUE="\033[1;34m"
  readonly COLOR_CYAN="\033[1;36m"
fi

trap 'printf "%b" "$COLOR_RESET"' EXIT ERR INT TERM

logo() {
  printf '%b' "$COLOR_CYAN"
  sed 's/^/  /' <<'EOF'

██╗  ██╗██╗   ██╗██████╗ ██████╗ ███╗   ██╗██╗██████╗ ██╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗████╗  ██║██║██╔══██╗██║
███████║ ╚████╔╝ ██████╔╝██████╔╝██╔██╗ ██║██║██████╔╝██║
██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║╚██╗██║██║██╔══██╗██║
██║  ██║   ██║   ██║     ██║  ██║██║ ╚████║██║██║  ██║██║
╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝
EOF
  printf '%b\n' "$COLOR_RESET"
  printf '%bWelcome to Hyprniri dotfiles installer!%b\n\n' "$COLOR_GREEN" "$COLOR_RESET"
}

log() {
  local level="${1:-}"
  shift || true
  local message="$*"

  if [[ -z "$level" ]] || [[ -z "$message" ]]; then
    printf 'ERROR: log() requires a level and a message\n' >&2
    return 1
  fi

  local color="$COLOR_RESET"
  case "${level^^}" in
  INFO) color="$COLOR_GREEN" ;;
  WARN) color="$COLOR_YELLOW" ;;
  ERROR) color="$COLOR_RED" ;;
  STEP)
    printf '\n%b::%b %s\n\n' "$COLOR_BLUE" "$COLOR_RESET" "$message" >&2
    return 0
    ;;
  *)
    printf 'ERROR: Invalid log level: %s\n' "$level" >&2
    return 1
    ;;
  esac

  printf '%b%s:%b %b\n' "$color" "${level^^}" "$COLOR_RESET" "$message" >&2
}

die() {
  log ERROR "$1"
  exit "${2:-1}"
}

ensure_dependencies_installed() {
  local -a pm_query_cmd pm_install_cmd
  local -a base_packages core_dev_package=()

  base_packages=(git chezmoi figlet)

  if command -v dnf >/dev/null 2>&1; then
    pm_query_cmd=(rpm -q)
    pm_install_cmd=(sudo dnf install -y)

  elif command -v pacman >/dev/null 2>&1; then
    pm_query_cmd=(pacman -Q)
    pm_install_cmd=(sudo pacman -S --needed --noconfirm)
    core_dev_package=("base-devel")

  else
    die "Unsupported distribution - neither dnf nor pacman found"
  fi

  local -a required_packages=("${base_packages[@]}" "${core_dev_package[@]}")
  local -a to_install=()
  local pkg

  log STEP "Checking for required packages..."
  for pkg in "${required_packages[@]}"; do
    if ! "${pm_query_cmd[@]}" "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if [[ "${#to_install[@]}" -eq 0 ]]; then
    log INFO "All required packages already installed"
    return 0
  fi

  log STEP "Installing missing packages: ${to_install[*]}"
  if "${pm_install_cmd[@]}" "${to_install[@]}"; then
    log INFO "Required packages installed successfully"
  else
    die "Failed to install required packages"
  fi
}

backup_config_if_needed() {
  if [[ ! -d "${HOME}/.config" ]]; then
    return
  fi

  if [[ -z "$(find "${HOME}/.config" -mindepth 1 -maxdepth 1)" ]]; then
    return
  fi

  while true; do
    local response

    printf '%bBack up existing ~/.config before continuing?%b %b[Y/n]%b ' "$COLOR_BLUE" "$COLOR_RESET" "$COLOR_YELLOW" "$COLOR_RESET" >&2
    if ! read -r response </dev/tty; then
      log INFO "Input read failed. Skipping backup of ~/.config"
      return
    fi

    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
      local timestamp backup_dir
      timestamp=$(date -u +%Y%m%d%H%M%S)
      backup_dir="${HOME}/.config.backup.${timestamp}"

      if mv -n -- "${HOME}/.config" "$backup_dir"; then
        log INFO "Backed up existing ~/.config to ${backup_dir}"
        return
      else
        die "Failed to back up ~/.config to ${backup_dir}"
      fi
    elif [[ "$response" =~ ^[Nn]$ ]]; then
      log INFO "Skipping backup of ~/.config"
      return
    else
      printf '%bPlease enter Y/y (Yes), N/n (No), or press Enter for Yes.%b\n' "$COLOR_YELLOW" "$COLOR_RESET" >&2
    fi
  done
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "This script must not be run as root"
  fi

  if [[ "$(uname)" != "Linux" ]]; then
    die "This script only supports Linux"
  fi

  local arch
  arch="$(uname -m)"
  case "$arch" in
  x86_64 | amd64 | aarch64 | arm64) ;;
  *)
    die "Unsupported architecture: $arch"
    ;;
  esac

  logo
  ensure_dependencies_installed
  backup_config_if_needed

  clear
  exec chezmoi init --apply "$REPO" "$@"
}

main "$@"
