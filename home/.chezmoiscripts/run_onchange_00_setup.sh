#!/usr/bin/env bash

set -euo pipefail
# shellcheck disable=SC1091
source "${CHEZMOI_WORKING_TREE:?env variable missing. Please only run this script via chezmoi}/home/.chezmoiscripts/.00_helpers.sh"

# ------------------------------------------------------------------------------
# Install core dependencies
# ------------------------------------------------------------------------------
ask_for_sudo

deps=(
  "gum" "git"
)
for dep in "${deps[@]}"; do
  if ! command -v "$dep" &>/dev/null; then
    sudo pacman -S --noconfirm "$dep" || {
      log_error "Failed to install $dep. Please install it manually."
      exit 1
    }
  fi
done

# ------------------------------------------------------------------------------
# Setup Chaotic AUR repository
# ------------------------------------------------------------------------------
setup_chaotic_aur() {
  grep -q "chaotic-aur" /etc/pacman.conf && {
    log_info "Chaotic AUR repository is already configured"
    return 0
  }
  log_info "Setting up Chaotic AUR repository..."
  if sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com &&
    sudo pacman-key --lsign-key 3056513887B78AEB &&
    sudo pacman -U --noconfirm \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
      'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' &&
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf &&
    sudo pacman -Syyu --noconfirm; then
    log_success "Chaotic AUR repository setup completed successfully"
    return 0
  else
    log_warning "Failed to set up Chaotic AUR repository"
    log_info "You can set it up manually by following the instructions at https://aur.chaotic.cx/"
    return 1
  fi

}

if confirm_action "Setup Chaotic AUR repository?"; then
  setup_chaotic_aur

  AUR_HELPER="${AUR_HELPER:-$(get_user_choice "Choose your AUR helper" "paru" "yay")}"

  if ! has_command "$AUR_HELPER"; then
    install_package "$AUR_HELPER" || exit 1
    gum spin --title "Syncing AUR database" -- "$AUR_HELPER" -Syyu --noconfirm
  fi
else

  if ! has_command paru && ! has_command yay; then
    AUR_HELPER="${AUR_HELPER:-$(get_user_choice "Choose AUR helper to install manually" "paru" "yay")}"
    log_info "Installing $AUR_HELPER manually..."

    gum spin --title "Installing $AUR_HELPER" -- bash -c "
      cd /tmp
      git clone https://aur.archlinux.org/$AUR_HELPER.git
      cd $AUR_HELPER
      makepkg -si --noconfirm
    "
  fi
fi

# ------------------------------------------------------------------------------
# Install packages
# ------------------------------------------------------------------------------
packages=(
  "fish"
  "bat"
  "fzf"
  "ripgrep"
  "fd"
)
for package in "${packages[@]}"; do
  install_package "$package"
done
