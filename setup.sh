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
    popd >/dev/null || exit
    rm -rf "$tmpdir"
    exit 1
  }
  popd >/dev/null || exit
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

enable_services() {
  local user_services=(
    hyprpolkitagent.service
    gnome-keyring-daemon.socket
  )
  local system_services=(
    bluetooth.service
  )

  for service in "${user_services[@]}"; do
    if systemctl --user is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      systemctl --user enable "$service" || {
        printc red "Failed to enable $service."
        exit 1
      }
    fi
  done

  for service in "${system_services[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
      printc green "$service is already enabled."
    else
      printc yellow "Enabling $service..."
      sudo systemctl enable "$service" || {
        printc red "Failed to enable $service."
        exit 1
      }
    fi
  done
}

install_fonts() {
  local repo_url="https://github.com/Vantesh/Fonts.git"
  local temp_dir
  temp_dir=$(mktemp -d)
  local target_dir="$HOME/.local/share/fonts"
  local new_count=0
  local update_count=0

  printc yellow "Cloning fonts from $repo_url..."
  git clone --depth=1 "$repo_url" "$temp_dir" || {
    printc red "Failed to clone font repo."
    exit 1
  }

  mkdir -p "$target_dir"

  mapfile -t font_files < <(find "$temp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \))

  if [[ ${#font_files[@]} -eq 0 ]]; then
    printc red "No font files found in the repository."
    rm -rf "$temp_dir"
    return 1
  fi

  for font_file in "${font_files[@]}"; do
    font_name=$(basename "$font_file")
    target_font="$target_dir/$font_name"

    if [[ -f "$target_font" ]]; then
      if ! cmp -s "$font_file" "$target_font"; then
        cp "$font_file" "$target_font"
        ((update_count++))
      fi
    else
      cp "$font_file" "$target_font"
      ((new_count++))
    fi
  done

  if ((new_count > 0 || update_count > 0)); then
    printc yellow "Refreshing font cache..."
    fc-cache -f "$target_dir"
    printc green "Installed $new_count new fonts and updated $update_count fonts."
  else
    printc green "All fonts are already up to date."
  fi

  rm -rf "$temp_dir"
}

# --- Main ---
main() {
  configure_pacman
  install_yay
  install_dependencies
  enable_services
  install_fonts
}

main "$@"
