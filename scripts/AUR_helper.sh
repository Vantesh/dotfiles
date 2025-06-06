#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly AVAILABLE_AUR_HELPERS=("yay" "paru")

# =============================================================================
# USER INTERACTION FUNCTIONS
# =============================================================================

get_user_choice() {
  local input=""
  local index=0

  printc_box "AUR HELPER SELECTION" "1) yay (default) 2) paru"

  while true; do
    printc magenta "Enter your choice [1-2] or press Enter for default: "
    printc -n cyan "> "
    read -r input

    case "$input" in
    "" | "1" | "yay")
      index=0
      break
      ;;
    "2" | "paru")
      index=1
      break
      ;;
    *)
      printc red "Invalid choice. Please try again."
      echo
      ;;
    esac
  done

  AUR_HELPER="${AVAILABLE_AUR_HELPERS[$index]}"
}

# =============================================================================
# AUR HELPER INSTALLATION FUNCTIONS
# =============================================================================

check_existing_aur_helper() {
  if has_cmd "$AUR_HELPER"; then
    printc green "$AUR_HELPER is already installed."
    return 0
  fi
  return 1
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
  (
    cd "$temp_dir" || exit
    makepkg -si --noconfirm &>/dev/null
  ) || {
    rm -rf "$temp_dir"
    fail "Failed to build and install $AUR_HELPER."
  }
}

install_aur_helper() {
  if check_existing_aur_helper; then
    return 0
  fi

  printc -n cyan "Installing $AUR_HELPER..."
  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temporary directory."

  clone_aur_helper_repository "$temp_dir"
  build_and_install_aur_helper "$temp_dir"

  printc green "OK"
  rm -rf "$temp_dir"
}

# =============================================================================
# DATABASE SYNCHRONIZATION
# =============================================================================

sync_aur_database() {
  printc -n cyan "Synchronizing database..."
  "$AUR_HELPER" -Sy --noconfirm &>/dev/null || {
    fail "Failed to synchronize AUR database."
  }
  printc green "OK"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  get_user_choice
  install_aur_helper
  sync_aur_database
}

main
