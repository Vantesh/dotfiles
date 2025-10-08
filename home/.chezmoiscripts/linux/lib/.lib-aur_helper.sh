#!/usr/bin/env bash
# .lib-aur_helper.sh - AUR helper installation
#
# Installs paru from AUR if no AUR helper exists.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
# Exit codes:
#   0 (success), 1 (failure)

export LAST_ERROR="${LAST_ERROR:-}"

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

# Installs AUR helper if none exists.
#
# Skips if paru or yay already installed. Otherwise builds paru-bin from AUR
# and generates paru development database.
#
# Globals:
#   LAST_ERROR - Set on failure
# Returns:
#   0 on success or if helper already exists, 1 on failure
install_aur_helper() {
  local temp_dir=""

  LAST_ERROR=""

  command_exists paru && return 0
  command_exists yay && return 0

  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create temp directory"
    return 1
  }

  trap '[[ -d "${temp_dir:-}" ]] && rm -rf "${temp_dir}"' RETURN EXIT ERR

  if ! _build_aur_package "$PARU_REPO" "paru-bin" "$temp_dir/paru-bin"; then
    return 1
  fi

  if ! paru --gendb >/dev/null 2>&1; then
    LAST_ERROR="Failed to generate paru development database"
    return 1
  fi

  return 0
}
