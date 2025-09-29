#!/usr/bin/env bash

# Chezmoi bootstrap script
# Do not remove the env "NOT_PERSONAL=1" else some scripts will fail

set -euo pipefail
IFS=$'\n\t'

readonly INSTALLER_URL="https://git.io/chezmoi"
readonly DEFAULT_BIN_DIR="${HOME}/.local/bin"
readonly REPO="https://github.com/vantesh/dotfiles"

logo() {
  printf '\033[1;36m'
  sed 's/^/  /' <<'EOF'

██╗  ██╗██╗   ██╗██████╗ ██████╗ ███╗   ██╗██╗██████╗ ██╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗████╗  ██║██║██╔══██╗██║
███████║ ╚████╔╝ ██████╔╝██████╔╝██╔██╗ ██║██║██████╔╝██║
██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║╚██╗██║██║██╔══██╗██║
██║  ██║   ██║   ██║     ██║  ██║██║ ╚████║██║██║  ██║██║
╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝
EOF
  printf '\033[0m\n'
  printf "\033[1;32mWelcome to Hyprniri dotfiles installer!\033[0m\n"
  printf "\n"
}

log() {
  local level=$1
  shift || true
  local message="$*"
  local color="\033[0m"
  case "${level^^}" in
  INFO) color="\033[1;32m" ;;
  WARN) color="\033[1;33m" ;;
  ERROR) color="\033[1;31m" ;;
  esac
  printf '%b[%s]%b %s\n' "$color" "${level^^}" "\033[0m" "$message" >&2
}

die() {
  log ERROR "$1"
  exit "${2:-1}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_chezmoi() {
  local bin_dir="$1"
  log INFO "Installing chezmoi to ${bin_dir}..."

  if command_exists curl; then
    curl -fsSL "${INSTALLER_URL}" | sh -s -- -b "$bin_dir"
  elif command_exists wget; then
    wget -qO- "${INSTALLER_URL}" | sh -s -- -b "$bin_dir"
  else
    die "Installation requires curl or wget."
  fi
}

ensure_chezmoi_installed() {
  local bin_dir="${DEFAULT_BIN_DIR}"
  local path

  if command_exists chezmoi; then
    path=$(command -v chezmoi)
    printf "%s\n" "$path"
    return
  fi

  mkdir -p "$bin_dir"
  install_chezmoi "$bin_dir"

  path="${bin_dir}/chezmoi"
  [ -x "$path" ] || die "chezmoi executable not found at ${path}"
  printf "%s\n" "$path"
}

backup_config_if_needed() {
  if [ ! -d "${HOME}/.config" ]; then
    return
  fi

  if [ -z "$(find "${HOME}/.config" -mindepth 1 -maxdepth 1)" ]; then
    return
  fi

  local prompt=$'\033[1;36mBack up existing ~/.config before continuing?\033[0m \033[1;33m[Y/n]\033[0m '

  while true; do
    local response

    if ! read -rp "$prompt" response </dev/tty; then
      log INFO "Input read failed. Skipping backup of ~/.config."
      return
    fi

    if [[ "$response" =~ ^[Yy]$ || -z "$response" ]]; then
      local timestamp backup_dir
      timestamp=$(date -u +%Y%m%d%H%M%S)
      backup_dir="${HOME}/.config.backup.${timestamp}"

      if mv -n "${HOME}/.config" "$backup_dir"; then
        log INFO "Backed up existing ~/.config to ${backup_dir}."
        return
      else
        die "Failed to back up ~/.config to ${backup_dir}."
      fi
    elif [[ "$response" =~ ^[Nn]$ ]]; then
      log INFO "Skipping backup of ~/.config."
      return
    else
      echo "Please enter Y/y (Yes), N/n (No), or press Enter for Yes." >&2
    fi
  done
}

run_chezmoi_init() {
  local chezmoi_bin="$1"
  shift
  printf "\n"
  exec env NOT_PERSONAL=1 "$chezmoi_bin" init --apply "$REPO" "$@"
}

main() {

  if [ "$(id -u)" -eq 0 ]; then
    die "This script must not be run as root."
  fi

  local chezmoi_bin
  logo
  chezmoi_bin=$(ensure_chezmoi_installed)
  backup_config_if_needed
  run_chezmoi_init "$chezmoi_bin" "$@"
}

main "$@"
