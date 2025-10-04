#!/usr/bin/env bash
# .package_manager.sh - Package installation and management
# Exit codes: 0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)
#
# NOTE: install_package() logs SKIP messages for already-installed packages.
# This is an intentional exception to the "silent library" pattern for better UX.

export LAST_ERROR="${LAST_ERROR:-}"

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
    dnf list --installed "$package_name" >/dev/null 2>&1
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
