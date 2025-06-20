#!/bin/bash

# =============================================================================
# CONSTANTS
# =============================================================================
DEPS=(
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
  ugrep
  bat
  fzf
  trash-cli
)

readonly ZSHENV_FILE="/etc/zsh/zshenv"
readonly ZSH_CONFIG_DIR="/etc/zsh"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  printc cyan "Installing ZSH dependencies..."
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done
  printc green "Dependencies installed successfully."
}

# =============================================================================
# ZSH CONFIGURATION FUNCTIONS
# =============================================================================

create_zsh_config_directory() {
  if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
    printc cyan "Creating ZSH configuration directory..."
    sudo mkdir -p "$ZSH_CONFIG_DIR" || fail "Failed to create ZSH configuration directory."
    printc green "ZSH configuration directory created at $ZSH_CONFIG_DIR."
  fi
}

setup_zshenv() {

  create_zsh_config_directory

  write_system_config "$ZSHENV_FILE" "ZSH environment configuration" <<'EOF'

# ZSH environment file

# This file is sourced by ZSH at startup to set environment variables.
# XDG BASE DIRS

# export XDG Base Directories
if [[ -z "$XDG_CONFIG_HOME" ]]; then
  export XDG_CONFIG_HOME="$HOME/.config"
fi

if [[ -z "$XDG_DATA_HOME" ]]; then
  export XDG_DATA_HOME="$HOME/.local/share"
fi

if [[ -z "$XDG_CACHE_HOME" ]]; then
  export XDG_CACHE_HOME="$HOME/.cache"
fi

if [[ -z "$XDG_STATE_HOME" ]]; then
  export XDG_STATE_HOME="$HOME/.local/state"
fi

# export ZDOTDIR
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
else
  export ZDOTDIR="$HOME/.config/zsh"
fi

# export PATH
 export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

EOF

  if [[ -f "$ZSHENV_FILE" ]]; then
    printc green "ZSH environment file created at $ZSHENV_FILE"
  else
    fail "Failed to create ZSH environment file at $ZSHENV_FILE"
  fi
}

set_default_shell() {
  printc cyan "Setting ZSH as default shell..."
  local zsh_path
  zsh_path=$(which zsh) || fail "Failed to find ZSH executable."
  echo
  chsh -s "$zsh_path" "$USER" || fail "Failed to set ZSH as default shell."
  printc green "ZSH set as default shell for user $USER."
}

# =============================================================================
# DATABASE AND CACHE UPDATES
# =============================================================================

update_pkgfile_database() {
  printc -n cyan "Updating pkgfile database..."
  sudo pkgfile --update >/dev/null || fail "Failed to update pkgfile database."
  printc green "OK"
}

rebuild_bat_cache() {
  printc -n cyan "Rebuilding bat cache..."
  bat cache --build >/dev/null || fail "Failed to rebuild bat cache."
  printc green "OK"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  install_dependencies
  setup_zshenv
  set_default_shell
  update_pkgfile_database
  rebuild_bat_cache

  printc green "ZSH setup completed successfully."
}

main
