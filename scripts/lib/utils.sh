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
