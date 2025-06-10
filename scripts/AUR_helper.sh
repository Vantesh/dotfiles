#!/bin/bash

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

clone_aur_helper_repository() {
  local temp_dir="$1"
  git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to clone $AUR_HELPER repository."
  }
}

build_and_install_aur_helper() {
  local temp_dir="$1"
  (
    cd "$temp_dir" || exit
    makepkg -si --noconfirm &>/dev/null
  ) || {
    rm -rf "$temp_dir"
    fail "Failed to build and install $AUR_HELPER."
  }
}

install_aur_helper() {
  if has_cmd "$AUR_HELPER"; then
    printc yellow "$AUR_HELPER is already installed."
    return
  else

    printc cyan "Installing $AUR_HELPER..."
    local temp_dir
    temp_dir=$(mktemp -d) || fail "Failed to create temporary directory."

    clone_aur_helper_repository "$temp_dir"
    build_and_install_aur_helper "$temp_dir"

    printc green "$AUR_HELPER installed successfully."
    rm -rf "$temp_dir"
  fi
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
  ensure_sudo
  printc -n cyan "Synchronizing database..."

  "$AUR_HELPER" -Sy --noconfirm &>/dev/null || {
    fail "Failed"
  }
  printc green "OK"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  echo
  get_user_choice
  install_aur_helper
  configure_paru
  sync_aur_database
}

main
