#!/bin/bash
deps=(
  oh-my-posh-bin
  zsh
  zoxide
  unzip
  duf
  fastfetch
  eza
  fd
  less

)

# Install dependencies with yay
for dep in "${deps[@]}"; do
  install_package "$dep"
done
