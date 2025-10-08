#!/usr/bin/env bash
# .lib-aur_helper.sh - AUR helper installation
#
# Installs paru from AUR or detects existing AUR helper (paru/yay).
# Sets AUR_HELPER environment variable for use by other scripts.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   AUR_HELPER - Set to detected/installed helper name
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args)

export LAST_ERROR="${LAST_ERROR:-}"
export AUR_HELPER="${AUR_HELPER:-}"

readonly AUR_BASE_URL="https://aur.archlinux.org"
readonly PARU_REPO="${AUR_BASE_URL}/paru-bin.git"

_build_aur_package() {
  local repo_url="$1"
  local package_name="$2"
  local build_dir="$3"

  if ! git clone "$repo_url" "$build_dir" >/dev/null 2>&1; then
    LAST_ERROR="Failed to clone $package_name"
    return 1
  fi

  (
    cd "$build_dir" || exit 1
    makepkg -si --noconfirm
  ) >/dev/null 2>&1 || {
    LAST_ERROR="Failed to build $package_name"
    return 1
  }

  return 0
}

# Installs or detects AUR helper.
#
# Checks for existing paru or yay, otherwise builds paru-bin from AUR.
# Generates paru development database after first install.
#
# Globals:
#   LAST_ERROR - Set on failure
#   AUR_HELPER - Set to helper name: "paru" or "yay"
# Returns:
#   0 on success, 1 on failure
install_aur_helper() {
  local temp_dir=""

  LAST_ERROR=""

  if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
    return 0
  fi

  if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
    return 0
  fi

  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create temp directory"
    return 1
  }

  trap 'rm -rf "${temp_dir:-}"' EXIT ERR INT TERM

  if ! _build_aur_package "$PARU_REPO" "paru-bin" "$temp_dir/paru-bin"; then
    return 1
  fi

  if ! paru --gendb >/dev/null 2>&1; then
    LAST_ERROR="Failed to generate paru development database"
    return 1
  fi

  AUR_HELPER="paru"
  return 0
}
