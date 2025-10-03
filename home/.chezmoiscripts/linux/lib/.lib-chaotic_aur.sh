#!/usr/bin/env bash
# .chaotic_aur.sh - Chaotic-AUR repository setup for Arch Linux
# Exit codes: 0 (success), 1 (failure)

export LAST_ERROR="${LAST_ERROR:-}"

readonly CHAOTIC_KEY="3056513887B78AEB"
readonly CHAOTIC_KEYSERVER="keyserver.ubuntu.com"
readonly CHAOTIC_CDN="https://cdn-mirror.chaotic.cx/chaotic-aur"
readonly CHAOTIC_KEYRING_URL="${CHAOTIC_CDN}/chaotic-keyring.pkg.tar.zst"
readonly CHAOTIC_MIRRORLIST_URL="${CHAOTIC_CDN}/chaotic-mirrorlist.pkg.tar.zst"
readonly PACMAN_CONF="/etc/pacman.conf"
readonly MIRRORLIST_PATH="/etc/pacman.d/chaotic-mirrorlist"

chaotic_repo_configured() {
  grep -q "^\[chaotic-aur\]" "$PACMAN_CONF" 2>/dev/null
}

_chaotic_gpg_key_exists() {
  sudo pacman-key --list-keys "$CHAOTIC_KEY" >/dev/null 2>&1
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

  if _chaotic_gpg_key_exists; then
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

_sync_pacman_databases() {
  LAST_ERROR=""

  if ! sudo pacman -Sy --noconfirm >/dev/null 2>&1; then
    LAST_ERROR="Failed to sync pacman databases"
    return 1
  fi

  return 0
}

setup_chaotic_aur() {
  LAST_ERROR=""

  if ! _import_chaotic_gpg_key; then
    return 1
  fi

  if ! _install_package_from_url "chaotic-keyring" "$CHAOTIC_KEYRING_URL"; then
    return 1
  fi

  if ! _install_package_from_url "chaotic-mirrorlist" "$CHAOTIC_MIRRORLIST_URL"; then
    return 1
  fi

  if ! _add_chaotic_repo_to_pacman; then
    return 1
  fi

  if ! _sync_pacman_databases; then
    return 1
  fi

  return 0
}
