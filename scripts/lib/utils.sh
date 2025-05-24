#!/bin/bash

# --- Load color map ---
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/colors.sh"
# --- Print colored messages ---
printc() {
  local color_key="${1,,}"
  shift
  local color="${COLORS[$color_key]:-${COLORS[white]}}"
  echo -e "${color}$*${COLORS[white]}"
}

# --- Check if command exists ---
has_cmd() {
  command -v "$1" &>/dev/null
}

# --- Confirm action ---
confirm() {
  read -rp "$(printc yellow "$1 [y/N]: ")" response
  [[ "$response" =~ ^[Yy]$ ]]
}

# --- Safe exit with message ---
fail() {
  printc red "$1"
  exit "${2:-1}"
}

update_or_append_config() {
  local config_file="$1"
  local key="$2"
  local value="$3"
  local line="${key}=${value}"

  # Ensure the file exists
  if [[ ! -f "$config_file" ]]; then
    sudo touch "$config_file"
    sudo chown root:root "$config_file"
    sudo chmod 644 "$config_file"
  fi

  # Check if the key (commented or not) already exists
  if sudo grep -qE "^\s*#?\s*${key}=" "$config_file"; then
    # Update the existing line
    if sudo sed -i "s|^\s*#\?\s*${key}=.*|${line}|" "$config_file"; then
      printc green "Updated $key to $value in $config_file"
    else
      fail "Failed to update $key"
    fi
  else
    # Append on a new line if key doesn't exist
    if echo -e "\n$line" | sudo tee -a "$config_file" >/dev/null; then
      printc green "Appended $key=$value to $config_file"
    else
      fail "Failed to append $key"
    fi
  fi
}
