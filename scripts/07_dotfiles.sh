#!/bin/bash

#link config files
cp -r .config ~/
#chmode +x
chmod_config_folders=(
  hypr
  waybar

)
for folder in "${chmod_config_folders[@]}"; do
  config_dir="$HOME/.config/$folder"
  if [ -d "$config_dir" ]; then
    find "$config_dir" -type f -name "*.sh" -exec chmod +x {} \;
    if [ $? -ne 0 ]; then
      echo "Error: Failed to chmod .sh files in $config_dir" >&2
    fi
    find "$config_dir" -type f -name "*.py" -exec chmod +x {} \;
    if [ $? -ne 0 ]; then
      echo "Error: Failed to chmod .py files in $config_dir" >&2
    fi
  else
    echo "Warning: Directory $config_dir does not exist." >&2
  fi
done
