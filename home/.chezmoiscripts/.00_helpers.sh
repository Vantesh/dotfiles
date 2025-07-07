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
log_fail() { printf "${RED}[FAILED]${RESET} %b\n" "$1"; }

# ------------------------------------------------------------------------------
# System Utilities
# ------------------------------------------------------------------------------
has_command() { command -v "$1" &>/dev/null; }

ask_for_sudo() {
  sudo -n true 2>/dev/null || {
    log_info "This script requires sudo privileges\n"
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

get_user_choices() {
  local prompt="$1"
  shift
  gum choose --no-show-help --cursor "▶ " --header "$prompt" --no-limit "$@"
}

write_system_config() {
  local config_file="$1"
  local description="$2"
  shift 2

  if sudo mkdir -p "$(dirname "$config_file")" && sudo tee "$config_file" >/dev/null; then
    log_success "Written ${MAGENTA}$description${RESET} to $config_file"
  else
    log_fail "Failed to write ${MAGENTA}$description${RESET} to $config_file"
    return 1
  fi
}

# Enable systemd services
enable_service() {
  local service="$1" scope="${2:-system}"
  local prefix=()
  local cmd=("systemctl")

  if [[ $scope == "user" ]]; then
    cmd+=("--user")
  else
    prefix=(sudo)
  fi

  # Handle template services (services with @)
  local template_service=""
  if [[ "$service" == *@*.service ]]; then
    template_service="${service%@*}@.service"
  fi

  # Check if service or template exists
  local service_exists=false

  # Check if service is available in systemctl list-unit-files
  if "${prefix[@]}" "${cmd[@]}" list-unit-files "$service" &>/dev/null; then
    service_exists=true
  elif [[ -n "$template_service" ]] && "${prefix[@]}" "${cmd[@]}" list-unit-files "$template_service" &>/dev/null; then
    service_exists=true
  # Check if service file exists in filesystem
  elif [[ -f "/etc/systemd/system/$service" || -f "/usr/lib/systemd/system/$service" ]]; then
    service_exists=true
  elif [[ -n "$template_service" ]] && [[ -f "/etc/systemd/system/$template_service" || -f "/usr/lib/systemd/system/$template_service" ]]; then
    service_exists=true
  # Check user systemd directories if user scope
  elif [[ "$scope" == "user" ]] && [[ -f "$HOME/.config/systemd/user/$service" || -f "/usr/lib/systemd/user/$service" ]]; then
    service_exists=true
  fi

  if [[ "$service_exists" == true ]]; then
    # Skip if already enabled
    if "${prefix[@]}" "${cmd[@]}" is-enabled "$service" &>/dev/null; then
      log_info "${MAGENTA}$service${RESET} ($scope) already enabled"
    else
      if "${prefix[@]}" "${cmd[@]}" enable "$service" &>/dev/null; then
        log_success "Enabled ${MAGENTA}$service${RESET} ($scope)"
      else
        log_fail "Failed to enable ${MAGENTA}$service${RESET} ($scope)"
        return 1
      fi
    fi
  else
    log_warning "${MAGENTA}$service${RESET} ($scope) not found"
  fi
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
    log_info "${MAGENTA}$package${RESET} already installed"
    return 0
  }

  pm="$(get_package_manager)" || return 1

  if [[ "$pm" == "pacman" ]]; then
    ask_for_sudo
    if gum spin --spinner line --title "Installing $package..." -- sudo pacman -S --noconfirm "$package"; then
      log_success "${MAGENTA}$package${RESET} installed"
    else
      log_fail "Failed to install ${MAGENTA}$package${RESET} (skipping)"
      return 0 # Return 0 to continue script execution
    fi
  else
    if gum spin --spinner line --title "Installing $package..." -- "$pm" -S --noconfirm "$package"; then
      log_success "${MAGENTA}$package${RESET} installed"
    else
      log_fail "Failed to install ${MAGENTA}$package${RESET} (skipping)"
      return 0 # Return 0 to continue script execution
    fi
  fi
}

# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" == "${0}" ]]; then
  log_error "This file should be sourced, not executed directly"
  exit 1
fi
