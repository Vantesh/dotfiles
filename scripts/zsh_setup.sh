#!/bin/bash

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
  imagemagick # Image manipulation
  chafa       # Image to ASCII converter
)

readonly ZSHENV_FILE="/etc/zsh/zshenv"
readonly ZSH_CONFIG_DIR="/etc/zsh"
readonly ZDOTDIR="$HOME/.config/zsh"
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
  printc cyan "Setting ZSH as default shell..."
  local zsh_path
  zsh_path=$(command -v zsh) || fail "ZSH not found."
  chsh -s "$zsh_path" "$USER" || fail "Failed to set ZSH as default shell."

  if echo && confirm "Set ZSH as default shell for root?"; then
    printc cyan "Setting ZSH as default shell for all users..."
    sudo chsh -s "$zsh_path" || fail "Failed to set ZSH for all users."

    if [[ ! -d "/root/.config" ]]; then
      sudo mkdir -p "/root/.config" || fail "Failed to create .config directory for root."
      sudo chown root:root "/root/.config"
    fi
    sudo cp -r "$ZDOTDIR" "/root/.config/" || fail "Failed to copy ZSH config files for root."

    printc green "ZSH set as default shell for all users."
  else
    printc yellow "Skipping setting ZSH as default shell for all users."
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
# GIT CONFIGURATION
# =============================================================================
setup_git_config() {
  local config_dir="$HOME/.config/git"
  local config_file="$config_dir/.localconfig"
  printc cyan "Setting up Git configuration..."

  if [[ ! -f "$config_file" ]]; then
    mkdir -p "$config_dir" || fail "Failed to create Git config directory."
  fi

  read -rp "Enter your Git user name: " git_user_name
  read -rp "Enter your Git user email: " git_user_email

  cat > "$config_file" <<EOF
[user]
  name = $git_user_name
  email = $git_user_email
EOF

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
  zsh_pacman_hook
  update_pkgfile_database
  rebuild_bat_cache
  if confirm "Set up Git configuration?"; then
    setup_git_config
  fi
}

main
