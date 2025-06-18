#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly CONFIG_SOURCE_DIR=".config"
readonly VSCODE_SOURCE_DIR=".vscode"
readonly LOCAL_BIN_SOURCE="local/bin"
readonly LOCAL_BIN_TARGET="$HOME/.local/bin"

readonly EXECUTABLE_CONFIG_FOLDERS=(
  hypr
  waybar
  rofi
)

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

copy_config_files() {
  printc -n cyan "Copying config files... "
  if [[ -d "$CONFIG_SOURCE_DIR" ]]; then
    if cp -r "$CONFIG_SOURCE_DIR" ~/; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  else
    fail "Source .config directory not found"
  fi
}

copy_vscode_config() {
  if pacman -Qe | grep -q "visual-studio-code-bin"; then
    printc -n cyan "Copying VSCode config... "
    if [[ -d "$VSCODE_SOURCE_DIR" ]]; then
      if cp -r "$VSCODE_SOURCE_DIR" ~/; then
        printc green "OK"
      else
        printc red "FAILED"
      fi
    else
      printc yellow "not found"
    fi
  fi
}

# =============================================================================
# PERMISSION MANAGEMENT FUNCTIONS
# =============================================================================

make_scripts_executable_in_folder() {
  local folder="$1"
  local config_dir="$HOME/.config/$folder"

  if [[ -d "$config_dir" ]]; then
    printc -n cyan "Making $folder scripts executable... "
    if find "$config_dir" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null; then
      printc green "OK"
    else
      printc red "FAILED"
      return 1
    fi
  fi
}

make_config_scripts_executable() {
  for folder in "${EXECUTABLE_CONFIG_FOLDERS[@]}"; do
    make_scripts_executable_in_folder "$folder"
  done
}

# =============================================================================
# SYSTEM SCRIPT INSTALLATION FUNCTIONS
# =============================================================================

copy_local_scripts() {
  if [[ ! -d "$LOCAL_BIN_TARGET" ]]; then
    printc -n cyan "Creating local bin directory... "
    if sudo mkdir -p "$LOCAL_BIN_TARGET"; then
      printc green "OK"
    else
      fail "FAILED"
    fi
  fi
  if [[ -d "$LOCAL_BIN_SOURCE" ]]; then
    printc -n cyan "Copying local scripts... "
    if sudo cp -r "$LOCAL_BIN_SOURCE"/* "$LOCAL_BIN_TARGET"/ && sudo chmod +x "$LOCAL_BIN_TARGET"/*; then
      printc green "OK"
    else
      fail "FAILED"
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
# WALLPAPER
# =============================================================================
# enable_service "wallpaper.timer" "user"

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  backup_existing_config
  copy_config_files
  copy_vscode_config
  make_config_scripts_executable
  copy_local_scripts
  setup_user_directories
  enable_service "wallpaper.timer" "user"
}

main
