#!/usr/bin/env bash
# Bootstrap yay from yay-bin when yay is unavailable.

export LAST_ERROR="${LAST_ERROR:-}"

install_aur_helper() {
  local temp_dir

  LAST_ERROR=""

  temp_dir="$(mktemp -d)" || {
    LAST_ERROR="Failed to create yay-bin build directory"
    return 1
  }

  if ! git clone https://aur.archlinux.org/yay-bin.git "$temp_dir/yay-bin" >/dev/null 2>&1; then
    rm -rf -- "$temp_dir"
    LAST_ERROR="Failed to clone yay-bin"
    return 1
  fi

  # Keep cleanup local to the build; do not replace the caller's traps.
  if ! (
    trap 'rm -rf -- "$temp_dir"' EXIT
    cd "$temp_dir/yay-bin" || exit 1
    makepkg -si --noconfirm
  ) >/dev/null 2>&1; then
    LAST_ERROR="Failed to build and install yay-bin"
    return 1
  fi
}
