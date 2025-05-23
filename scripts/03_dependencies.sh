#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"

# Source utils for printc and fail (adjust path if needed)
source "$ROOT_DIR/scripts/lib/utils.sh"

# Source dependencies arrays
source "$ROOT_DIR/dependencies"

install_dependencies() {
  # Combine all package arrays into one big array
  local all_packages=("${core_packages[@]}" "${fonts[@]}" "${appearance[@]}" "${input_tools[@]}")

  if [[ ${#all_packages[@]} -eq 0 ]]; then
    fail "No packages found in dependencies."
  fi

  printc yellow "Installing ${#all_packages[@]} packages..."

  # Install packages with yay
  yay -S --noconfirm --needed "${all_packages[@]}" || fail "Failed to install some dependencies."

  printc green "All dependencies installed successfully."
}

install_dependencies
