#!/usr/bin/env bash

# Environment Variables:
#   AUR_HELPER - Preferred AUR helper (default: paru)
#
# Return Codes:
#   0   - Success
#   1   - Operation failed (details in LAST_ERROR)
#   2   - Invalid arguments
#   127 - Required tool/dependency missing

set -euo pipefail

export LAST_ERROR="${LAST_ERROR:-}"

# Package manager detection cache
__package_manager_cache=""

get_package_manager() {
  # Return cached value if available
  if [[ -n "${__package_manager_cache:-}" ]]; then
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  # Detect dnf (Fedora and derivatives)
  if command -v dnf >/dev/null 2>&1; then
    __package_manager_cache="dnf"
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  # Detect pacman (Arch and derivatives)
  if command -v pacman >/dev/null 2>&1; then
    __package_manager_cache="pacman"
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  LAST_ERROR="No supported package manager detected (dnf or pacman required)"
  return 1
}

get_aur_helper() {
  local helper="${AUR_HELPER:-paru}"

  if ! command_exists "$helper"; then
    LAST_ERROR="AUR helper '$helper' is not available. Set AUR_HELPER to a valid helper (e.g., paru, yay)"
    return 127
  fi

  printf '%s\n' "$helper"
  return 0
}

package_exists() {
  local package_name="${1:-}"

  LAST_ERROR=""

  local manager
  if ! manager="$(get_package_manager)"; then
    return 1
  fi

  case "$manager" in
  dnf)
    dnf list --installed "$package_name" >/dev/null 2>&1
    ;;
  pacman)
    # On Arch, use AUR helper to check both official and AUR packages
    local aur_helper
    if ! aur_helper="$(get_aur_helper)"; then
      return 127
    fi
    "$aur_helper" -Qi "$package_name" >/dev/null 2>&1
    ;;
  *)
    LAST_ERROR="Unsupported package manager: $manager"
    return 1
    ;;
  esac
}

install_package() {
  local package_name="${1:-}"

  LAST_ERROR=""

  # Detect package manager
  local manager
  if ! manager="$(get_package_manager)"; then
    return 1
  fi

  # Install package based on manager
  case "$manager" in
  dnf)
    if ! sudo dnf install -y "$package_name"; then
      LAST_ERROR="Failed to install '$package_name' with dnf"
      return 1
    fi
    ;;
  pacman)
    local aur_helper
    if ! aur_helper="$(get_aur_helper)"; then
      return 127
    fi

    if ! "$aur_helper" -S --needed --noconfirm "$package_name"; then
      LAST_ERROR="Failed to install '$package_name' with $aur_helper"
      return 1
    fi
    ;;
  *)
    LAST_ERROR="Unsupported package manager: $manager"
    return 1
    ;;
  esac

  return 0
}
