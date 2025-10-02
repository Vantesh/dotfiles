#!/usr/bin/env bash

# Return Codes:
#   0   - Success (helper already installed or newly installed)
#   1   - Installation failed (details in LAST_ERROR)
#   2   - Invalid arguments

set -euo pipefail

export LAST_ERROR="${LAST_ERROR:-}"
export AUR_HELPER="${AUR_HELPER:-}"

# Constants
readonly AUR_BASE_URL="https://aur.archlinux.org"
readonly PARU_REPO="${AUR_BASE_URL}/paru-bin.git"
readonly YAY_REPO="${AUR_BASE_URL}/yay-bin.git"

_build_aur_package() {
  local repo_url="$1"
  local package_name="$2"
  local build_dir="$3"

  if ! git clone "$repo_url" "$build_dir" >/dev/null 2>&1; then
    LAST_ERROR="Failed to clone repository: $repo_url"
    return 1
  fi

  if ! (cd "$build_dir" && makepkg -si --noconfirm >/dev/null 2>&1); then
    LAST_ERROR="Failed to build and install $package_name"
    return 1
  fi

  return 0
}

install_aur_helper() {
  local preferred_helper="paru" # Default to paru
  local temp_dir=""

  # Clear previous error
  LAST_ERROR=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --paru)
      preferred_helper="paru"
      shift
      ;;
    --yay)
      preferred_helper="yay"
      shift
      ;;
    *)
      LAST_ERROR="Invalid argument: $1. Use --paru or --yay"
      return 2
      ;;
    esac
  done

  if pacman -Qi "$preferred_helper" &>/dev/null; then
    AUR_HELPER="$preferred_helper"
    return 0
  fi

  # Create temporary build directory
  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create temporary directory"
    return 1
  }

  # Ensure cleanup on exit
  trap 'rm -rf "$temp_dir"' EXIT ERR INT TERM

  # Install selected helper
  case "$preferred_helper" in
  paru)
    if ! _build_aur_package "$PARU_REPO" "paru-bin" "$temp_dir/paru-bin"; then
      return 1
    fi
    ;;
  yay)
    if ! _build_aur_package "$YAY_REPO" "yay-bin" "$temp_dir/yay-bin"; then
      return 1
    fi
    ;;
  *)
    LAST_ERROR="Unsupported AUR helper: $preferred_helper"
    return 2
    ;;
  esac

  AUR_HELPER="$preferred_helper"
  return 0
}
