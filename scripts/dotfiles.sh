#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly EXECUTABLE_CONFIG_FOLDERS=(
  hypr
  waybar
  rofi
)

# =============================================================================
# DEPENDENCY FUNCTIONS
# =============================================================================

check_stow() {
  if ! command -v stow &> /dev/null; then
    install_package stow
  fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

backup_existing_config() {
  if [[ -d "$HOME/.config" ]]; then
    printc -n cyan "Backing up .config... "
    if backup_with_timestamp "$HOME/.config" "$HOME" >/dev/null 2>&1; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  fi
}

# =============================================================================
# DOTFILES INSTALLATION FUNCTIONS
# =============================================================================

stow_dotfiles() {
  local script_dir current_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dotfiles_root
  dotfiles_root="$(dirname "$script_dir")"
  local home_dir="$dotfiles_root/home"
  
  if [[ ! -d "$home_dir" ]]; then
    fail "Home directory not found: $home_dir"
  fi
  
  printc -n cyan "Stowing dotfiles... "
  current_dir="$(pwd)"
  
  # Change to the home directory and run stow
  if cd "$home_dir" && stow . --target="$HOME" --adopt; then
    printc green "OK"
    cd "$current_dir" || return 1
  else
    cd "$current_dir" || return 1
    fail "FAILED"
  fi
}

copy_local_scripts() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local dotfiles_root
  dotfiles_root="$(dirname "$script_dir")"
  local local_bin_source="$dotfiles_root/home/.local/bin"
  local local_bin_target="$HOME/.local/bin"
  
  if [[ ! -d "$local_bin_target" ]]; then
    printc -n cyan "Creating local bin directory... "
    if mkdir -p "$local_bin_target"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  fi
  
  if [[ -d "$local_bin_source" ]]; then
    printc -n cyan "Copying local scripts... "
    if cp -r "$local_bin_source"/* "$local_bin_target"/; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  fi
}


# =============================================================================
# PERMISSION MANAGEMENT FUNCTIONS
# =============================================================================

make_scripts_executable_in_folder() {
  local folder="$1"
  local base_path="$2"
  local description="$3"
  
  if [[ -d "$base_path/$folder" ]]; then
    printc -n cyan "Making $description scripts executable... "
    if find "$base_path/$folder" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  fi
}

make_all_scripts_executable() {
  # Make config scripts executable
  for folder in "${EXECUTABLE_CONFIG_FOLDERS[@]}"; do
    make_scripts_executable_in_folder "$folder" "$HOME/.config" "$folder"
  done
  
  # Make local bin scripts executable
  if [[ -d "$HOME/.local/bin" ]]; then
    printc -n cyan "Making local bin scripts executable... "
    if find "$HOME/.local/bin" -type f -exec chmod +x {} \; 2>/dev/null; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  fi
}



# =============================================================================
# USER DIRECTORY SETUP FUNCTIONS
# =============================================================================

setup_user_directories() {
  if ! has_cmd xdg-user-dirs-update; then
    install_package xdg-user-dirs
  fi

  printc -n cyan "Setting up user directories... "
  if xdg-user-dirs-update; then
    printc green "OK"
  else
    fail "FAILED"
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  check_stow
  backup_existing_config
  stow_dotfiles
  copy_local_scripts
  make_all_scripts_executable
  setup_user_directories
}

main
