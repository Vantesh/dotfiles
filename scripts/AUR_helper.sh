#!/bin/bash

get_choice() {
  local aur_helpers=("yay" "paru")
  local input=""
  local index=0

  while true; do
    printc cyan "\nAvailable AUR helpers:\n"
    for i in "${!aur_helpers[@]}"; do
      printc yellow "  $((i + 1)). ${aur_helpers[i]}"
    done

    printc cyan "\nPlease select an AUR helper to install (1-${#aur_helpers[@]}): (default is 'yay'): "
    read -r input

    if [[ -z "$input" ]]; then
      index=0
      break
    elif [[ "$input" =~ ^[1-9]$ ]] && ((input >= 1 && input <= ${#aur_helpers[@]})); then
      index=$((input - 1))
      break
    else
      printc red "Invalid input. Please enter a number between 1 and ${#aur_helpers[@]}, or press Enter to default to 'yay'."
    fi
  done

  AUR_HELPER="${aur_helpers[$index]}"
  printc cyan "Installing $AUR_HELPER as the AUR helper."
}

install_aur_helper() {
  if command -v "$AUR_HELPER" &>/dev/null; then
    printc green "$AUR_HELPER is already installed."
    return
  fi

  printc cyan "Installing $AUR_HELPER..."

  temp_dir=$(mktemp -d)
  git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$temp_dir" || {
    fail "Failed to clone $AUR_HELPER repository."
  }

  (
    cd "$temp_dir" || exit
    makepkg -si --noconfirm
  ) || {
    rm -rf "$temp_dir"
    fail "Failed to build and install $AUR_HELPER."
  }

  printc green "$AUR_HELPER installed successfully."
  rm -rf "$temp_dir"
}

get_choice
install_aur_helper

# sync the AUR database
printc cyan "Synchronizing database..."
"$AUR_HELPER" -Syu --noconfirm || {
  fail "Failed to synchronize AUR database."
}
