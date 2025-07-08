#!/bin/bash

# Source helpers
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/home/.chezmoiscripts/.00_helpers.sh"

# =============================================================================
# CONSTANTS
# =============================================================================

readonly AVAILABLE_AUR_HELPERS=("yay" "paru")

get_user_choice() {
  AUR_HELPER=$(choice "Choose your preferred AUR helper:" "${AVAILABLE_AUR_HELPERS[@]}") || {
    fail "No AUR helper selected. Exiting."
  }
}

# =============================================================================
# AUR HELPER INSTALLATION FUNCTIONS
# =============================================================================

has_chaotic_aur() {
  grep -q "chaotic-aur" /etc/pacman.conf
}

clone_aur_helper_repository() {
  local temp_dir="$1"
  git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to clone $AUR_HELPER repository."
  }
}

build_and_install_aur_helper() {
  local temp_dir="$1"
  pushd "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to enter $temp_dir"
  }
  if makepkg -si --noconfirm &>/dev/null; then
    popd &>/dev/null || exit
  else
    popd &>/dev/null || exit
    rm -rf "$temp_dir"
    fail "Failed to build and install $AUR_HELPER."
  fi
}

install_aur_helper() {
  if has_cmd "$AUR_HELPER"; then
    printc green "$AUR_HELPER is already installed"
    return
  fi

  # Try installing from Chaotic AUR first if available
  if has_chaotic_aur; then
    printc -n cyan "Installing $AUR_HELPER from Chaotic AUR repository..."
    if sudo pacman -S --noconfirm "$AUR_HELPER" &>/dev/null; then
      printc green "OK"
      return
    else
      printc yellow "Failed to install from repository, falling back to manual build."
    fi
  fi

  # Fall back to manual build
  printc cyan "Building $AUR_HELPER from source..."
  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temporary directory."

  clone_aur_helper_repository "$temp_dir"
  pushd "$temp_dir" &>/dev/null || exit
  build_and_install_aur_helper "$temp_dir"
  popd &>/dev/null || exit

  printc green "$AUR_HELPER installed successfully."
  rm -rf "$temp_dir"
}

configure_paru() {
  if [[ "$AUR_HELPER" == "paru" ]]; then
    printc -n cyan "Configuring paru... "
    if ! sudo sed -i 's/^#BottomUp/BottomUp/' /etc/paru.conf; then
      fail "Fail"
    fi
    printc green "OK"
  fi
}

# =============================================================================
# DATABASE SYNCHRONIZATION
# =============================================================================

sync_aur_database() {
  printc -n cyan "Synchronizing database..."

  "$AUR_HELPER" -Sy --noconfirm &>/dev/null || {
    fail "Failed"
  }
  printc green "OK"
}

# Main execution
echo
get_user_choice
install_aur_helper
configure_paru
sync_aur_database
