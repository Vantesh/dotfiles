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
yay -S --needed --noconfirm "${deps[@]}"
