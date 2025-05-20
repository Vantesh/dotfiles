#!/bin/bash

# Hyprland dotfiles setup script for Arch Linux

# --- Color Map ---
declare -A COLORS=(
  [red]='\033[0;31m'
  [green]='\033[0;32m'
  [yellow]='\033[1;33m'
  [white]='\033[0m'
)


printc() {
  local color_key="${1,,}"
  shift
  local color="${COLORS[$color_key]:-${COLORS[white]}}"
  echo -e "${color}$*${COLORS[white]}"
}

# --- Patch pacman.conf with custom options ---
configure_pacman() {
  local config="/etc/pacman.conf"
  local backup="${config}.bak"

  printc yellow "Configuring pacman..."

  [[ -f "$config" ]] || {
    printc red "pacman.conf not found at $config. Aborting."
    exit 1
  }

  sudo cp "$config" "$backup" || {
    printc red "Failed to backup pacman.conf. Aborting."
    exit 1
  }

  for option in "Color" "VerbosePkgLists"; do
    if grep -qE "^#?$option" "$config"; then
      sudo sed -i "s/^#\?$option/$option/" "$config"
      printc green "Enabled '$option'"
    else
      printc yellow "'$option' already active or missing."
    fi
  done

  if ! grep -q "^ILoveCandy" "$config"; then
    sudo sed -i "/^Color/a ILoveCandy" "$config"
    printc green "Inserted 'ILoveCandy' after 'Color'"
  else
    printc yellow "ILoveCandy already present."
  fi
}

# --- Install yay from AUR if missing ---
install_yay() {
  if command -v yay &>/dev/null; then
    printc yellow "yay is already installed."
    return
  fi

  printc yellow "Installing yay from AUR..."

  sudo pacman -S --noconfirm --needed git base-devel || {
    printc red "Failed to install build dependencies."
    exit 1
  }

  local tmpdir
  tmpdir=$(mktemp -d) || {
    printc red "Failed to create temp directory."
    exit 1
  }

  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir" || {
    printc red "Failed to clone yay repository."
    rm -rf "$tmpdir"
    exit 1
  }

  pushd "$tmpdir" >/dev/null || exit 1
  makepkg -si --noconfirm || {
    printc red "yay build or install failed."
    popd >/dev/null
    rm -rf "$tmpdir"
    exit 1
  }
  popd >/dev/null
  rm -rf "$tmpdir"

  printc green "yay installed successfully."
}

# --- Install packages from dependencies.txt ---
install_dependencies() {
  local deps_file="dependencies.txt"

  [[ -f "$deps_file" ]] || {
    printc red "Missing $deps_file. Please create it and list required packages."
    exit 1
  }

  printc yellow "Installing dependencies from $deps_file..."

  mapfile -t packages < <(grep -Ev '^\s*#|^\s*$' "$deps_file")

  for pkg in "${packages[@]}"; do
    if pacman -Qq "$pkg" &>/dev/null; then
      printc green "$pkg is already installed."
    else
      printc yellow "Installing $pkg..."
      yay -S --noconfirm "$pkg" || {
        printc red "Failed to install $pkg."
        exit 1
      }
    fi
  done

  printc green "All dependencies installed."
}

# --- Main ---
main() {
  configure_pacman
  install_yay
  install_dependencies
}

main "$@"
