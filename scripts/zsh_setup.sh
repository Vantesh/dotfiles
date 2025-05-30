#!/bin/bash
deps=(
  oh-my-posh-bin
  zsh
  zoxide
  unzip
  duf
  fastfetch
  dust
  pkgfile
  topgrade
  eza
  fd
  less
  ripgrep
  bat
  fzf

)

# Install dependencies
for dep in "${deps[@]}"; do
  install_package "$dep"
done

# setup zshenv
ZSHENV_FILE="/etc/zsh/zshenv"
if [[ ! -d "/etc/zsh" ]]; then
  sudo mkdir -p /etc/zsh
fi
printc cyan "Setting up $ZSHENV_FILE..."
sudo tee "$ZSHENV_FILE" >/dev/null <<EOF
# ZSH environment file
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
else
  export ZDOTDIR="$HOME/.config/zsh"
fi
EOF

if [[ -f "$ZSHENV_FILE" ]]; then
  printc green "ZSH environment file created at $ZSHENV_FILE"
else
  fail "Failed to create ZSH environment file at $ZSHENV_FILE"
fi

# make sure zsh is the default shell
chsh -s "$(which zsh)" "$USER"
