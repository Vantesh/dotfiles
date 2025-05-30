#!/bin/bash

#backup existing dotfiles
if [ -d "$HOME/.config" ]; then
  printc "green" "Backing up existing .config directory to .config_backup"
  mv "$HOME/.config" "$HOME/.config_backup"
else
  echo "No existing .config directory found, skipping backup."
fi

#copy new dotfiles
printc "cyan" "Copying new dotfiles to $HOME/.config"
cp -r .config ~/

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
