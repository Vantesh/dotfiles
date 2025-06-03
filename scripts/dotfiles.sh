#!/bin/bash

#backup existing dotfiles
if [ -d "$HOME/.config" ]; then
  printc "green" "Backing up existing .config directory to .config_backup"
  mv "$HOME/.config" "$HOME/.config_backup"
else
  echo "No existing .config directory found, skipping backup."
fi

#copy new dotfiles
printc "cyan" "Applying dotfiles"
cp -r .config ~/

if pacman -Qe | grep -q "visual-studio-code-bin"; then
  cp -r .vscode ~/
else
  echo "visual-studio-code-bin is not installed, skipping .vscode copy."
fi

# make scripts executable
chmod_config_folders=(
  hypr
  waybar
  rofi

)
for folder in "${chmod_config_folders[@]}"; do
  config_dir="$HOME/.config/$folder"
  if [ -d "$config_dir" ]; then
    if ! find "$config_dir" -type f -name "*.sh" -exec chmod +x {} \;; then
      echo "Error: Failed to chmod .sh files in $config_dir" >&2
    fi
    if ! find "$config_dir" -type f -name "*.py" -exec chmod +x {} \;; then
      echo "Error: Failed to chmod .py files in $config_dir" >&2
    fi
  else
    echo "Warning: Directory $config_dir does not exist." >&2
  fi
done

# copy local to usr/local/bin
printc "cyan" "Copying scripts to /usr/local/bin"
if [ -d "local/bin" ]; then
  sudo cp -r local/bin/* /usr/local/bin/
  sudo chmod +x /usr/local/bin/*
else
 printc yellow "No local/bin directory found, skipping copy."
fi

# run xdg-user-dirs-update to populate user directories
if ! has_cmd xdg-user-dirs-update; then
  install_package xdg-user-dirs
else
  printc "cyan" "Running xdg-user-dirs-update"
  xdg-user-dirs-update || {
    fail "Failed to run xdg-user-dirs-update. Please check your installation."
  }
fi
