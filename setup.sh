#!/bin/bash

# Hyprland dotfiles setup script for Arch Linux

# 🎨 Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[0m'

#spice up pacman  with colors,progress bar and a ilovecandy

pacman_config() {
  local config="/etc/pacman.conf"
  local options=("Color" "VerbosePkgLists")
  local ilovecandy="ILoveCandy"

  echo "🛠️  Configuring pacman..."

  # Backup first
  sudo cp "$config" "${config}.bak"

  # Enable regular options if commented out
  for option in "${options[@]}"; do
    if grep -q "^#${option}" "$config"; then
      sudo sed -i "s/^#${option}/${option}/" "$config"
      echo "Enabled ${option}"
    else
      echo "${option} already enabled or missing."
    fi
  done

  # Ensure ILoveCandy is present
  if ! grep -q "^${ilovecandy}" "$config"; then
    echo -e "\n${ilovecandy}" | sudo tee -a "$config" >/dev/null
    echo "🍬 Added ILoveCandy to pacman.conf"
  else
    echo "🍭 ILoveCandy already present."
  fi
}

pacman_config
# 📦 Install yay if not already available
install_yay() {
  if ! command -v yay &>/dev/null; then
    print "$YELLOW" "Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"
    pushd "$tmpdir" >/dev/null || exit 1
    makepkg -si --noconfirm
    popd >/dev/null || exit
    rm -rf "$tmpdir"
    print "$GREEN" "yay installed successfully."
  else
    print "$GREEN" "yay is already installed."
  fi
}

# 📦 Install packages listed in dependencies.txt
install_dependencies() {
  local deps_file="dependencies.txt"

  if [[ ! -f "$deps_file" ]]; then
    print "$RED" "Missing $deps_file. Exiting..."
    exit 1
  fi

  mapfile -t packages < <(grep -Ev '^\s*#|^\s*$' "$deps_file")

  for pkg in "${packages[@]}"; do
    if ! pacman -Qq "$pkg" &>/dev/null; then
      print "$YELLOW" "Installing $pkg..."
      yay -S --noconfirm "$pkg" || {
        print "$RED" "Failed to install $pkg. Exiting..."
        exit 1
      }
    else
      print "$GREEN" "$pkg is already installed."
    fi
  done
}

# 🚀 Run the setup
install_yay
install_dependencies
