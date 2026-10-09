#!/usr/bin/env bash
# Bootstrap paru only when neither supported AUR helper is available.

export LAST_ERROR="${LAST_ERROR:-}"

install_aur_helper() {
  local temp_dir

  LAST_ERROR=""
  command_exists paru && return 0
  command_exists yay && return 0

  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create paru build directory"
    return 1
  }

  if ! git clone https://aur.archlinux.org/paru.git "$temp_dir/paru" >/dev/null 2>&1; then
    rm -rf -- "$temp_dir"
    LAST_ERROR="Failed to clone paru"
    return 1
  fi

  # Keep cleanup local to the build; do not replace the caller's traps.
  if ! (
    trap 'rm -rf -- "$temp_dir"' EXIT
    cd "$temp_dir/paru" || exit 1
    makepkg -si --noconfirm
  ) >/dev/null 2>&1; then
    LAST_ERROR="Failed to build and install paru"
    return 1
  fi

  if ! command_exists paru; then
    LAST_ERROR="paru is unavailable after installation"
    return 1
  fi
}
