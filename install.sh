#!/bin/sh
#
# chezmoi bootstrap script
#

set -e

# --- Logging Functions ---
log_info() {
  printf "\033[1;34m==>\033[0m %s\n" "$1" >&2
}

log_error() {
  printf "\033[1;31m==> ERROR:\033[0m %s\n" "$1" >&2
}

# --- Ensure chezmoi is installed ---
ensure_chezmoi_installed() {

  bin_dir="${HOME}/.local/bin"
  chezmoi_bin="${bin_dir}/chezmoi"
  mkdir -p "$bin_dir"

  if command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi"
    return
  fi

  log_info "chezmoi not found. Installing to ${bin_dir}..."

  if command -v curl >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif command -v wget >/dev/null 2>&1; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    log_error "To install chezmoi, you must have curl or wget."
    exit 1
  fi

  echo "$chezmoi_bin"
}

# --- Backup .config  ---
backup_config_if_needed() {
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"
  backup_marker="${state_dir}/backup-done"

  [ -f "$backup_marker" ] && return

  if [ -d "${HOME}/.config" ]; then
    backup_dir="${HOME}/.config.backup.$(date +%Y%m%d%H%M%S)"
    log_info "Backing up existing ~/.config to ${backup_dir}"
    mv "${HOME}/.config" "$backup_dir"
  fi

  mkdir -p "$state_dir"
  touch "$backup_marker"
}

# --- Main Execution ---
chezmoi_bin=$(ensure_chezmoi_installed)
backup_config_if_needed

# Resolve the script directory
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

log_info "Initializing dotfiles setup"
printf "\n"

exec "$chezmoi_bin" init --apply "--source=$script_dir"
