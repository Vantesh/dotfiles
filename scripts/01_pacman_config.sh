#!/bin/bash

configure_pacman() {
  local config="/etc/pacman.conf"
  local backup="${config}.bak"

  printc yellow "Configuring pacman..."

  [[ -f "$config" ]] || fail "pacman.conf not found at $config. Aborting."

  sudo cp "$config" "$backup" || fail "Failed to backup pacman.conf. Aborting."

  for option in Color VerbosePkgLists; do
    if grep -qE "^#?$option" "$config"; then
      sudo sed -i "s/^#\?$option/$option/" "$config" && printc green "Enabled '$option'" || fail "Failed to enable '$option'"
    else
      printc yellow "'$option' already active or missing."
    fi
  done

  if ! grep -q "^ILoveCandy" "$config"; then
    sudo sed -i "/^Color/a ILoveCandy" "$config" && printc green "Inserted 'ILoveCandy' after 'Color'" || fail "Failed to insert 'ILoveCandy'"
  else
    printc yellow "ILoveCandy already present."
  fi
}

configure_pacman
