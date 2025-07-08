#!/bin/bash

# Source helpers
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/home/.chezmoiscripts/.00_helpers.sh"

# =============================================================================
# CONSTANTS
# =============================================================================
DEPS=(
  oh-my-posh-bin
  zsh
  zoxide
  duf
  fastfetch
  dust
  pkgfile
  topgrade
  eza
  fd
  ugrep
  bat
  fzf
  frei-bin
  curlie
  tealdeer
  ouch
  ripgrep
  imagemagick # Image manipulation
  chafa       # Image to ASCII converter
)

readonly ZSHENV_FILE="/etc/zsh/zshenv"
readonly ZSH_CONFIG_DIR="/etc/zsh"

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
  for dep in "${DEPS[@]}"; do
    install_package "$dep"
  done
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

EOF

  if [[ -f "$ZSHENV_FILE" ]]; then
    printc green "ZSH environment file created at $ZSHENV_FILE"
  else
    fail "Failed to create ZSH environment file at $ZSHENV_FILE"
  fi
}

set_default_shell() {
  local zsh_path
  zsh_path=$(command -v zsh) || fail "ZSH not found."

  # Check if ZSH is already the default shell for current user
  if [[ "$SHELL" == "$zsh_path" ]]; then
    printc green "ZSH is already the default shell for $USER"
  else
    printc cyan "Setting ZSH as default shell for $USER..."
    chsh -s "$zsh_path" "$USER" || fail "Failed to set ZSH as default shell."
    printc green "ZSH set as default shell for $USER"
  fi

  if echo && confirm "Set ZSH as default shell for root?"; then
    # Check if ZSH is already the default shell for root
    local root_shell
    root_shell=$(sudo getent passwd root | cut -d: -f7)
    if [[ "$root_shell" == "$zsh_path" ]]; then
      printc green "ZSH is already the default shell for root"
    else
      printc cyan "Setting ZSH as default shell for root..."
      sudo chsh -s "$zsh_path" || fail "Failed to set ZSH for root."
      printc green "ZSH set as default shell for root"
    fi

    if [[ ! -d "/root/.config" ]]; then
      sudo mkdir -p "/root/.config" || fail "Failed to create .config directory for root."
      sudo chown root:root "/root/.config"
    fi

    # Copy config folders for root
    local config_folders=("zsh" "fsh" "ohmyposh")
    for folder in "${config_folders[@]}"; do
      if [[ -d "$HOME/.config/$folder" ]]; then
        sudo cp -r "$HOME/.config/$folder" "/root/.config/$folder" || fail "Failed to copy $folder config for root."
      fi
    done

    printc green "ZSH configuration copied for root."
  else
    printc yellow "Skipping setting ZSH as default shell for root."
  fi
}

zsh_pacman_hook() {
  write_system_config "/etc/pacman.d/hooks/zsh.hook" "Zsh hook" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Path
Target = usr/bin/*

[Action]
Depends = zsh
Depends = procps-ng
Description = Reloading zsh shell...
When = PostTransaction
Exec = /usr/bin/pkill zsh --signal=USR1
EOF
}

# =============================================================================
# DATABASE AND CACHE UPDATES
# =============================================================================

update_pkgfile_database() {
  printc -n cyan "Updating pkgfile database..."
  sudo pkgfile --update >/dev/null || fail "Failed to update pkgfile database."
  printc green "OK"
  enable_service "pkgfile-update.timer" "system"
}

rebuild_bat_cache() {
  printc -n cyan "Rebuilding bat cache..."
  bat cache --build >/dev/null || fail "Failed to rebuild bat cache."
  printc green "OK"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

printc_box "ZSH SETUP" "Configuring ZSH shell and tools"

install_dependencies
setup_zshenv
set_default_shell
zsh_pacman_hook
update_pkgfile_database
rebuild_bat_cache
