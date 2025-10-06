#!/usr/bin/env bash

# Chezmoi bootstrap script
# Do not remove the env "NOT_PERSONAL=1" else some scripts will fail

set -euo pipefail
IFS=$'\n\t'

readonly REPO="https://github.com/vantesh/dotfiles"

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 2 ]] || [[ "${TERM:-}" = "dumb" ]]; then
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

readonly -a REQUIRED_PACKAGES=(git chezmoi figlet)

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
  printf '%bWelcome to Hyprniri dotfiles installer!%b\n\n' "$COLOR_INFO" "$COLOR_RESET"
}

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
  log ERROR "$1"
  exit "${2:-1}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_with_dnf() {
  local -a packages=("$@")

  log STEP "Using dnf to install required packages"

  if sudo dnf install -y "${packages[@]}"; then
    log INFO "Required packages installed successfully"
    return 0
  fi

  return 1
}

install_with_pacman() {
  local -a packages=("$@")

  log INFO "Using pacman to install required packages"

  if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
    log INFO "Required packages installed successfully"
    return 0
  fi

  return 1
}

ensure_dependencies_installed() {
  local missing_packages=()

  local pkg
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! command_exists "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done

  if [[ "${#missing_packages[@]}" -eq 0 ]]; then
    log INFO "Required commands already installed. Skipping dependency installation"
    return
  fi

  if command_exists dnf; then
    if install_with_dnf "${missing_packages[@]}"; then
      return
    fi
    die "Failed to install required packages with dnf"
  fi

  if command_exists pacman; then
    if install_with_pacman "${missing_packages[@]}"; then
      return
    fi
    die "Failed to install required packages with pacman"
  fi

  die "Unsupported distribution"
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

    printf '%bBack up existing ~/.config before continuing?%b %b[Y/n]%b ' "$COLOR_STEP" "$COLOR_RESET" "$COLOR_WARN" "$COLOR_RESET" >&2
    if ! read -r response </dev/tty; then
      log INFO "Input read failed. Skipping backup of ~/.config"
      return
    fi

    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
      local timestamp backup_dir
      timestamp=$(date -u +%Y%m%d%H%M%S)
      backup_dir="${HOME}/.config.backup.${timestamp}"

      if mv -n "${HOME}/.config" "$backup_dir"; then
        log INFO "Backed up existing ~/.config to ${backup_dir}"
        return
      else
        die "Failed to back up ~/.config to ${backup_dir}"
      fi
    elif [[ "$response" =~ ^[Nn]$ ]]; then
      log INFO "Skipping backup of ~/.config"
      return
    else
      printf '%bPlease enter Y/y (Yes), N/n (No), or press Enter for Yes.%b\n' "$COLOR_WARN" "$COLOR_RESET" >&2
    fi
  done
}

run_chezmoi_init() {
  clear
  exec env NOT_PERSONAL=1 chezmoi init --apply "$REPO" "$@"
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "This script must not be run as root"
  fi

  if [[ "$(uname -)" != "Linux" ]]; then
    die "This script only supports Linux"
  fi

  ARCH="$(uname -m)"
  case "$ARCH" in
  x86_64 | amd64 | aarch64 | arm64) ;;
  *)
    die "Unsupported architecture: $ARCH"
    ;;
  esac

  logo
  ensure_dependencies_installed
  backup_config_if_needed
  run_chezmoi_init "$@"
}

main "$@"
