#!/bin/bash

install_yay() {
  if has_cmd yay; then
    printc yellow "yay is already installed."
    return 0
  fi

  printc yellow "Installing yay from AUR..."

  # Install build dependencies
  sudo pacman -S --noconfirm --needed git base-devel || fail "Failed to install build dependencies."

  local tmpdir
  tmpdir=$(mktemp -d) || fail "Failed to create temp directory."

  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir" || {
    rm -rf "$tmpdir"
    fail "Failed to clone yay repository."
  }

  pushd "$tmpdir" >/dev/null || fail "Failed to enter temp directory."

  makepkg -si --noconfirm || {
    popd >/dev/null || true
    rm -rf "$tmpdir"
    fail "yay build or install failed."
  }

  popd >/dev/null || fail "Failed to exit temp directory."
  rm -rf "$tmpdir"

  printc green "yay installed successfully."
}

install_yay
