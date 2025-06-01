#!/bin/bash

configure_pacman() {
  local config="/etc/pacman.conf"
  local backup="${config}.bak"

  printc cyan "Configuring pacman..."

  [[ -f "$config" ]] || fail "pacman.conf not found at $config. Aborting."

  sudo cp "$config" "$backup" || fail "Failed to backup pacman.conf. Aborting."

  # Enable options by uncommenting them
  for option in Color VerbosePkgLists; do
    if sudo grep -q "^\s*#\?\s*$option" "$config"; then
      sudo sed -i "s/^\s*#\?\s*${option}/${option}/" "$config" &&
        printc green "Enabled '${option}'" ||
        fail "Failed to enable '${option}'"
    else
      printc yellow "'${option}' already enabled or missing."
    fi
  done

  # Insert ILoveCandy after Color if not already present
  if ! sudo grep -q "^\s*ILoveCandy" "$config"; then
    sudo sed -i "/^\s*Color/a ILoveCandy" "$config" &&
      printc green "Inserted 'ILoveCandy'" ||
      fail "Failed to insert 'ILoveCandy'"
  else
    printc yellow "'ILoveCandy' already present."
  fi
}

configure_pacman
