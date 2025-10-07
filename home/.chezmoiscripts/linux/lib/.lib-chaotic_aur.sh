#!/usr/bin/env bash
# .lib-chaotic_aur.sh - Chaotic-AUR repository configuration
#
# Configures Chaotic-AUR repository for Arch Linux. Checks if already
# configured and installs necessary keyring and mirror list packages.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure)

export LAST_ERROR="${LAST_ERROR:-}"

readonly CHAOTIC_KEY="3056513887B78AEB"
readonly CHAOTIC_KEYSERVER="keyserver.ubuntu.com"
readonly CHAOTIC_PKG_URL="${CHAOTIC_PKG_URL:-https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst}"
readonly CHAOTIC_MIRROR_PKG_URL="${CHAOTIC_MIRROR_PKG_URL:-https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst}"
readonly PACMAN_CONF="/etc/pacman.conf"
readonly MIRRORLIST_PATH="/etc/pacman.d/chaotic-mirrorlist"

# Checks if Chaotic-AUR repository is configured.
#
# Verifies presence of chaotic-aur section in /etc/pacman.conf.
#
# Returns:
#   0 if configured, 1 if not configured
chaotic_repo_configured() {
  grep -q "^\[chaotic-aur\]" "$PACMAN_CONF" 2>/dev/null
}

_package_installed() {
  local package_name="${1:-}"

  if [[ -z "$package_name" ]]; then
    return 1
  fi

  pacman -Qi "$package_name" >/dev/null 2>&1
}

_import_chaotic_gpg_key() {
  LAST_ERROR=""

  if sudo pacman-key --list-keys "$CHAOTIC_KEY" >/dev/null 2>&1; then
    return 0
  fi

  if ! sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver "$CHAOTIC_KEYSERVER" >/dev/null 2>&1; then
    LAST_ERROR="Failed to receive GPG key"
    return 1
  fi

  if ! sudo pacman-key --lsign-key "$CHAOTIC_KEY" >/dev/null 2>&1; then
    LAST_ERROR="Failed to sign GPG key"
    return 1
  fi

  return 0
}

_install_package_from_url() {
  local package_name="${1:-}"
  local package_url="${2:-}"

  LAST_ERROR=""

  if _package_installed "$package_name"; then
    return 0
  fi

  if ! sudo pacman -U --noconfirm "$package_url" >/dev/null 2>&1; then
    LAST_ERROR="Failed to install $package_name"
    return 1
  fi

  return 0
}

_add_chaotic_repo_to_pacman() {
  LAST_ERROR=""

  if ! printf '\n[chaotic-aur]\nInclude = %s\n' "$MIRRORLIST_PATH" | sudo tee -a "$PACMAN_CONF" >/dev/null; then
    LAST_ERROR="Failed to add chaotic-aur to pacman.conf"
    return 1
  fi

  return 0
}

# Configures Chaotic-AUR repository.
#
# Imports GPG key, installs keyring and mirrorlist packages, adds repository
# to pacman.conf, and syncs package databases.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success, 1 on failure
setup_chaotic_aur() {
  LAST_ERROR=""

  if ! _import_chaotic_gpg_key; then
    return 1
  fi

  if ! _install_package_from_url "chaotic-keyring" "$CHAOTIC_PKG_URL"; then
    return 1
  fi

  if ! _install_package_from_url "chaotic-mirrorlist" "$CHAOTIC_MIRROR_PKG_URL"; then
    return 1
  fi

  if ! _add_chaotic_repo_to_pacman; then
    return 1
  fi

  if ! sudo pacman -Sy --noconfirm >/dev/null 2>&1; then
    LAST_ERROR="Failed to sync pacman databases"
    return 1
  fi

  return 0
}
