#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly AVAILABLE_AUR_HELPERS=("yay" "paru")
readonly DEFAULT_AUR_HELPER="yay"

# =============================================================================
# USER INTERACTION FUNCTIONS
# =============================================================================

display_aur_helper_menu() {
  printc cyan "\nAvailable AUR helpers:\n"
  for i in "${!AVAILABLE_AUR_HELPERS[@]}"; do
    printc yellow "  $((i + 1)). ${AVAILABLE_AUR_HELPERS[i]}"
  done
}

validate_user_input() {
  local input="$1"
  local max_options="${#AVAILABLE_AUR_HELPERS[@]}"

  if [[ -z "$input" ]]; then
    return 0 # Default choice
  elif [[ "$input" =~ ^[1-9]$ ]] && ((input >= 1 && input <= max_options)); then
    return 0 # Valid choice
  else
    return 1 # Invalid choice
  fi
}

get_user_choice() {
  local input=""
  local index=0

  while true; do
    display_aur_helper_menu

    printc cyan "\nPlease select an AUR helper to install (1-${#AVAILABLE_AUR_HELPERS[@]}): (default is '$DEFAULT_AUR_HELPER'): "
    read -r input

    if validate_user_input "$input"; then
      if [[ -z "$input" ]]; then
        index=0 # Default to first option (yay)
      else
        index=$((input - 1))
      fi
      break
    else
      printc red "Invalid input. Please enter a number between 1 and ${#AVAILABLE_AUR_HELPERS[@]}, or press Enter to default to '$DEFAULT_AUR_HELPER'."
    fi
  done

  AUR_HELPER="${AVAILABLE_AUR_HELPERS[$index]}"
  printc cyan "Selected $AUR_HELPER as the AUR helper."
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
  printc cyan "Cloning $AUR_HELPER repository..."
  git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$temp_dir" &>/dev/null || {
    rm -rf "$temp_dir"
    fail "Failed to clone $AUR_HELPER repository."
  }
}

build_and_install_aur_helper() {
  local temp_dir="$1"
  printc cyan "Building and installing $AUR_HELPER..."
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

  printc cyan "Installing $AUR_HELPER..."
  local temp_dir
  temp_dir=$(mktemp -d) || fail "Failed to create temporary directory."

  clone_aur_helper_repository "$temp_dir"
  build_and_install_aur_helper "$temp_dir"

  printc green "$AUR_HELPER installed successfully."
  rm -rf "$temp_dir"
}

# =============================================================================
# DATABASE SYNCHRONIZATION
# =============================================================================

sync_aur_database() {
  printc cyan "Synchronizing database..."
  "$AUR_HELPER" -Syu --noconfirm &>/dev/null || {
    fail "Failed to synchronize AUR database."
  }
  printc green "Database synchronized successfully."
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
