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
readonly PARU_REPO="${AUR_BASE_URL}/paru.git"

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
# Skips if paru or yay already installed.
# If Chaotic-AUR is selected, installs paru via pacman.
# Otherwise builds paru from source AUR package and generates paru development database.
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

  # When Chaotic-AUR is enabled, prefer repo package over AUR build.
  if [[ "${INSTALL_CHAOTIC_AUR:-0}" == "1" ]]; then
    if ! sudo pacman -S --needed --noconfirm paru >/dev/null 2>&1; then
      LAST_ERROR="Failed to install paru from pacman"
      return 1
    fi
    return 0
  fi

  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create temp directory"
    return 1
  }

  trap '[[ -d "${temp_dir:-}" ]] && rm -rf "${temp_dir}"' RETURN EXIT ERR

  if ! _build_aur_package "$PARU_REPO" "paru" "$temp_dir/paru"; then
    return 1
  fi

  if ! paru --gendb >/dev/null 2>&1; then
    LAST_ERROR="Failed to generate paru development database"
    return 1
  fi

  return 0
}
