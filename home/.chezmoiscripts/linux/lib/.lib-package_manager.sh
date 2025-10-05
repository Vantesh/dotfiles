#!/usr/bin/env bash
# .lib-package_manager.sh - Package installation and management
#
# Provides unified interface for package management across different distributions.
# Supports dnf (Fedora) and pacman+AUR (Arch). Handles package existence checks
# and installation with automatic manager detection.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   __package_manager_cache - Internal: cached package manager name
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

# Detects system package manager.
#
# Caches result for subsequent calls. Checks for dnf (Fedora) then
# pacman (Arch) in that order.
#
# Globals:
#   __package_manager_cache - Set with detected manager
#   LAST_ERROR - Set if no supported manager found
# Outputs:
#   Package manager name to stdout: "dnf" or "pacman"
# Returns:
#   0 on success, 1 if no supported manager found
get_package_manager() {
  if [[ -n "${__package_manager_cache:-}" ]]; then
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    __package_manager_cache="dnf"
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    __package_manager_cache="pacman"
    printf '%s\n' "$__package_manager_cache"
    return 0
  fi

  LAST_ERROR="No supported package manager detected (dnf or pacman required)"
  return 1
}

# Detects available AUR helper.
#
# Checks for paru first, then yay.
#
# Globals:
#   LAST_ERROR - Set if no helper found
# Outputs:
#   AUR helper name to stdout: "paru" or "yay"
# Returns:
#   0 on success, 127 if not found
get_aur_helper() {
  local helper=""

  if command -v paru >/dev/null 2>&1; then
    helper="paru"
  elif command -v yay >/dev/null 2>&1; then
    helper="yay"
  else
    LAST_ERROR="No AUR helper found (paru or yay required)"
    return 127
  fi

  printf '%s\n' "$helper"
  return 0
}

# Checks if package is installed.
#
# Uses appropriate command for detected package manager.
#
# Arguments:
#   $1 - Package name
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 if installed, 1 if not, 2 on invalid args, 127 if no AUR helper (Arch only)
package_exists() {
  local package_name="${1:-}"

  LAST_ERROR=""

  if [[ -z "$package_name" ]]; then
    LAST_ERROR="package_exists() requires package_name argument"
    return 2
  fi

  local manager
  if ! manager="$(get_package_manager)"; then
    return 1
  fi

  case "$manager" in
  dnf)
    rpm -q "$package_name" >/dev/null 2>&1
    ;;
  pacman)
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

# Installs packages using detected package manager.
#
# Skips already-installed packages with SKIP log message. Uses dnf or
# pacman+AUR helper based on distribution.
#
# Arguments:
#   $@ - Package names
# Globals:
#   LAST_ERROR - Set on failure
#   COLOR_INFO, COLOR_RESET - Used for SKIP message formatting
# Outputs:
#   SKIP messages to stderr via log() for already-installed packages
# Returns:
#   0 on success, 1 on failure, 2 on invalid args, 127 if no AUR helper (Arch only)
install_package() {
  LAST_ERROR=""

  if [[ $# -eq 0 ]]; then
    LAST_ERROR="install_package() requires at least one package name"
    return 2
  fi

  local manager
  if ! manager="$(get_package_manager)"; then
    return 1
  fi

  local -a packages_to_install=()
  local package_name

  for package_name in "$@"; do
    if package_exists "$package_name"; then
      log SKIP "${COLOR_INFO}${package_name}${COLOR_RESET} exists"
    else
      packages_to_install+=("$package_name")
    fi
  done

  if [[ ${#packages_to_install[@]} -eq 0 ]]; then
    return 0
  fi

  case "$manager" in
  dnf)
    if ! sudo dnf install -y "${packages_to_install[@]}"; then
      LAST_ERROR="Failed to install packages with dnf: ${packages_to_install[*]}"
      return 1
    fi
    ;;
  pacman)
    local aur_helper
    if ! aur_helper="$(get_aur_helper)"; then
      return 127
    fi

    if ! "$aur_helper" -S --needed --noconfirm "${packages_to_install[@]}"; then
      LAST_ERROR="Failed to install packages with $aur_helper: ${packages_to_install[*]}"
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

# Installs a group of packages with a descriptive name.
#
# Arguments:
#   $1 - Group name (for logging)
#   $@ - Package names
# Globals:
#   LAST_ERROR - Set on failure
#   COLOR_INFO, COLOR_RESET - Used for logging
# Outputs:
#   STEP messages to stderr via log()
# Returns:
#   0 on success, 1 on failure, 2 on invalid args, 127 if no AUR helper (Arch only)

install_group() {
  local group_name="$1"
  shift

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  log STEP "Installing $group_name packages"

  if ! install_package "$@"; then
    local error_msg="$LAST_ERROR"
    die "Failed to install $group_name packages: $error_msg"
  fi
}
