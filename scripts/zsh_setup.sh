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
  printc cyan "Setting up $ZSHENV_FILE..."

  create_zsh_config_directory

  sudo tee "$ZSHENV_FILE" >/dev/null <<EOF || fail "Failed to create ZSH environment file."
# ZSH environment file
if [[ -d "\$XDG_CONFIG_HOME/zsh" ]]; then
  export ZDOTDIR="\$XDG_CONFIG_HOME/zsh"
else
  export ZDOTDIR="\$HOME/.config/zsh"
fi
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
