#!/usr/bin/env bash

set -euo pipefail

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

chaotic_gpg_key_exists() {
  sudo pacman-key --list-keys "$CHAOTIC_KEY" >/dev/null 2>&1
}

package_installed() {
  local package_name="${1:-}"

  LAST_ERROR=""

  if [[ -z "$package_name" ]]; then
    LAST_ERROR="package_installed() requires a package name"
    return 2
  fi

  pacman -Qi "$package_name" >/dev/null 2>&1
}

import_chaotic_gpg_key() {

  LAST_ERROR=""

  if chaotic_gpg_key_exists; then
    return 0
  fi

  if ! sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver "$CHAOTIC_KEYSERVER" >/dev/null 2>&1; then
    LAST_ERROR="Failed to receive GPG key $CHAOTIC_KEY from $CHAOTIC_KEYSERVER"
    return 1
  fi

  if ! sudo pacman-key --lsign-key "$CHAOTIC_KEY" >/dev/null 2>&1; then
    LAST_ERROR="Failed to locally sign GPG key $CHAOTIC_KEY"
    return 1
  fi

  return 0
}

install_package_from_url() {
  local package_name="${1:-}"
  local package_url="${2:-}"

  LAST_ERROR=""

  if package_installed "$package_name"; then
    return 0
  fi

  if ! sudo pacman -U --noconfirm "$package_url" >/dev/null 2>&1; then
    LAST_ERROR="Failed to install $package_name from $package_url"
    return 1
  fi

  return 0
}

add_chaotic_repo_to_pacman() {
  LAST_ERROR=""

  if ! printf '\n[chaotic-aur]\nInclude = %s\n' "$MIRRORLIST_PATH" | sudo tee -a "$PACMAN_CONF" >/dev/null; then
    LAST_ERROR="Failed to add [chaotic-aur] to $PACMAN_CONF"
    return 1
  fi

  return 0
}

sync_pacman_databases() {
  LAST_ERROR=""

  if ! sudo pacman -Sy --noconfirm >/dev/null 2>&1; then
    LAST_ERROR="Failed to synchronize pacman databases"
    return 1
  fi

  return 0
}

setup_chaotic_aur() {
  LAST_ERROR=""

  if ! import_chaotic_gpg_key; then
    return 1
  fi

  if ! install_package_from_url "chaotic-keyring" "$CHAOTIC_KEYRING_URL"; then
    return 1
  fi

  if ! install_package_from_url "chaotic-mirrorlist" "$CHAOTIC_MIRRORLIST_URL"; then
    return 1
  fi

  if ! add_chaotic_repo_to_pacman; then
    return 1
  fi

  if ! sync_pacman_databases; then
    return 1
  fi

  return 0
}
