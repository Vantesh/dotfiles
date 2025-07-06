#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Color Constants
# ------------------------------------------------------------------------------
declare -r RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
declare -r CYAN='\033[0;36m' MAGENTA='\033[0;35m' RESET='\033[0m'

# ------------------------------------------------------------------------------
# Logging Functions
# ------------------------------------------------------------------------------
log_error() { printf "${RED}[ERROR]${RESET} %b\n" "$1" >&2; }
log_info() { printf "${CYAN}[INFO]${RESET} %b\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${RESET} %b\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING]${RESET} %b\n" "$1"; }

# ------------------------------------------------------------------------------
# System Utilities
# ------------------------------------------------------------------------------
has_command() { command -v "$1" &>/dev/null; }

ask_for_sudo() {
  sudo -n true 2>/dev/null || {
    log_info "This script requires sudo privileges"
    sudo -v
  }
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
}

confirm_action() { gum confirm --no-show-help --default="${2:-true}" "$1"; }

get_user_choice() {
  local prompt="$1"
  shift
  gum choose --no-show-help --cursor "▶ " --header "$prompt" "$@"
}

# ------------------------------------------------------------------------------
# Package Management
# ------------------------------------------------------------------------------
get_package_manager() {
  for pm in paru yay pacman; do
    has_command "$pm" && echo "$pm" && return
  done
  log_error "No supported package manager found" && return 1
}

is_package_installed() {
  local pm
  pm="$(get_package_manager)" || return 1
  "$pm" -Qi "$1" &>/dev/null
}

install_package() {
  local package="$1" pm
  is_package_installed "$package" && {
    log_info "${MAGENTA}$package${RESET} is already installed"
    return 0
  }

  pm="$(get_package_manager)" || return 1
  log_info "Installing ${MAGENTA}$package${RESET} using $pm..."

  if [[ "$pm" == "pacman" ]]; then
    ask_for_sudo
    gum spin --spinner line --title "Installing $package..." -- sudo pacman -S --noconfirm "$package"
  else
    gum spin --spinner line --title "Installing $package..." -- "$pm" -S --noconfirm "$package"
  fi

  if is_package_installed "$package"; then
    log_success "${MAGENTA}$package${RESET} installed successfully"
  else
    log_error "Failed to install ${MAGENTA}$package${RESET}"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" == "${0}" ]]; then
  log_error "This file should be sourced, not executed directly"
  exit 1
fi
