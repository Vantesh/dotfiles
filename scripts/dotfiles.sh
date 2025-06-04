#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================

readonly CONFIG_SOURCE_DIR=".config"
readonly VSCODE_SOURCE_DIR=".vscode"
readonly LOCAL_BIN_SOURCE="local/bin"
readonly LOCAL_BIN_TARGET="/usr/local/bin"

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
    printc cyan "Backing up existing .config directory..."
    backup_with_timestamp "$HOME/.config" "$HOME" || fail "Failed to backup existing .config directory."
  else
    printc yellow "No existing .config directory found, skipping backup."
  fi
}

# =============================================================================
# DOTFILES INSTALLATION FUNCTIONS
# =============================================================================

copy_config_files() {
  printc cyan "Applying dotfiles"
  if [[ -d "$CONFIG_SOURCE_DIR" ]]; then
    cp -r "$CONFIG_SOURCE_DIR" ~/ || fail "Failed to copy .config directory."
    printc green "Configuration files copied successfully."
  else
    fail "Source .config directory not found."
  fi
}

copy_vscode_config() {
  if pacman -Qe | grep -q "visual-studio-code-bin"; then
    printc cyan "Copying VSCode configuration..."
    if [[ -d "$VSCODE_SOURCE_DIR" ]]; then
      cp -r "$VSCODE_SOURCE_DIR" ~/ || fail "Failed to copy .vscode directory."
      printc green "VSCode configuration copied successfully."
    else
      printc yellow "VSCode source directory not found, skipping."
    fi
  else
    printc yellow "visual-studio-code-bin is not installed, skipping .vscode copy."
  fi
}

# =============================================================================
# PERMISSION MANAGEMENT FUNCTIONS
# =============================================================================

make_scripts_executable_in_folder() {
  local folder="$1"
  local config_dir="$HOME/.config/$folder"

  if [[ -d "$config_dir" ]]; then
    printc cyan "Making scripts executable in $folder..."

    if ! find "$config_dir" -type f -name "*.sh" -exec chmod +x {} \;; then
      printc red "Error: Failed to chmod .sh files in $config_dir"
      return 1
    fi

    if ! find "$config_dir" -type f -name "*.py" -exec chmod +x {} \;; then
      printc red "Error: Failed to chmod .py files in $config_dir"
      return 1
    fi

    printc green "Scripts in $folder made executable."
  else
    printc yellow "Warning: Directory $config_dir does not exist."
  fi
}

make_config_scripts_executable() {
  printc cyan "Making configuration scripts executable..."
  for folder in "${EXECUTABLE_CONFIG_FOLDERS[@]}"; do
    make_scripts_executable_in_folder "$folder"
  done
}

# =============================================================================
# SYSTEM SCRIPT INSTALLATION FUNCTIONS
# =============================================================================

copy_local_scripts() {
  printc cyan "Copying scripts to $LOCAL_BIN_TARGET"

  if [[ -d "$LOCAL_BIN_SOURCE" ]]; then
    sudo cp -r "$LOCAL_BIN_SOURCE"/* "$LOCAL_BIN_TARGET"/ || fail "Failed to copy local scripts."
    sudo chmod +x "$LOCAL_BIN_TARGET"/* || fail "Failed to make local scripts executable."
    printc green "Local scripts copied and made executable."
  else
    printc yellow "No $LOCAL_BIN_SOURCE directory found, skipping copy."
  fi
}

# =============================================================================
# USER DIRECTORY SETUP FUNCTIONS
# =============================================================================

setup_user_directories() {
  if ! has_cmd xdg-user-dirs-update; then
    printc cyan "Installing xdg-user-dirs..."
    install_package xdg-user-dirs
  fi

  printc cyan "Running xdg-user-dirs-update"
  xdg-user-dirs-update || fail "Failed to run xdg-user-dirs-update. Please check your installation."
  printc green "User directories updated successfully."
}

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

  printc green "Dotfiles installation completed successfully."
}

main
