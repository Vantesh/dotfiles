
#!/usr/bin/env bash
# Configure Chaotic-AUR before installing packages or an AUR helper.

export LAST_ERROR="${LAST_ERROR:-}"

readonly CHAOTIC_AUR_REPO="chaotic-aur"
readonly CHAOTIC_AUR_KEY="3056513887B78AEB"
readonly CHAOTIC_AUR_KEYSERVER="keyserver.ubuntu.com"
readonly CHAOTIC_AUR_URL="https://cdn-mirror.chaotic.cx/$CHAOTIC_AUR_REPO"
readonly CHAOTIC_AUR_MIRRORLIST="/etc/pacman.d/chaotic-mirrorlist"
readonly CHAOTIC_AUR_HELPER="yay"
readonly CHAOTIC_AUR_PACKAGES=(chaotic-keyring chaotic-mirrorlist)

import_chaotic_key() {
  if ! sudo pacman-key --list-keys "$CHAOTIC_AUR_KEY" >/dev/null 2>&1; then
    log INFO "Retrieving the official Chaotic-AUR signing key"

    if ! sudo pacman-key --recv-key "$CHAOTIC_AUR_KEY" \
      --keyserver "$CHAOTIC_AUR_KEYSERVER"; then
      LAST_ERROR="Failed to retrieve Chaotic-AUR signing key from $CHAOTIC_AUR_KEYSERVER"
      return 1
    fi
  fi

  log INFO "Locally signing the Chaotic-AUR key"

  if ! sudo pacman-key --lsign-key "$CHAOTIC_AUR_KEY"; then
    LAST_ERROR="Failed to locally sign Chaotic-AUR key"
    return 1
  fi
}

setup_chaotic_aur() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi"
  local update_marker="$state_dir/$CHAOTIC_AUR_REPO-updated"
  local repositories package
  local -a package_urls=()
  local install_trust=false enable_repo=false update_system=false

  LAST_ERROR=""

  if ! pacman -Q "${CHAOTIC_AUR_PACKAGES[@]}" >/dev/null 2>&1; then
    install_trust=true
  fi

  # Account for repositories configured through Include directives.
  if ! repositories=$(pacman-conf --repo-list); then
    LAST_ERROR="Failed to read the configured pacman repositories"
    return 1
  fi

  if ! grep -Fxq -- "$CHAOTIC_AUR_REPO" <<< "$repositories"; then
    enable_repo=true
  fi

  if [[ ! -f "$update_marker" || "$enable_repo" == true ]]; then
    update_system=true
  fi

  if [[ "$install_trust" == false &&
        "$enable_repo" == false &&
        "$update_system" == false ]]; then
    return 0
  fi

  print_box "Chaotic-AUR"

  if [[ "$install_trust" == true ]]; then
    if ! import_chaotic_key; then
      return 1
    fi

    for package in "${CHAOTIC_AUR_PACKAGES[@]}"; do
      package_urls+=("$CHAOTIC_AUR_URL/$package.pkg.tar.zst")
    done

    log INFO "Installing Chaotic-AUR keyring and mirrorlist"

    if ! sudo pacman -U --needed --noconfirm "${package_urls[@]}"; then
      LAST_ERROR="Failed to install Chaotic-AUR keyring and mirrorlist"
      return 1
    fi
  fi

  if [[ "$enable_repo" == true ]]; then
    log INFO "Enabling Chaotic-AUR repository"

    if ! printf '\n[%s]\nInclude = %s\n' \
      "$CHAOTIC_AUR_REPO" "$CHAOTIC_AUR_MIRRORLIST" |
      sudo tee -a /etc/pacman.conf >/dev/null; then
      LAST_ERROR="Failed to enable Chaotic-AUR in pacman.conf"
      return 1
    fi
  fi

  # Record success only after a successful full system update.
  if [[ "$update_system" == true ]]; then
    log STEP "Initial full system update"

    if ! sudo pacman -Syu --noconfirm; then
      LAST_ERROR="Initial full system update failed"
      return 1
    fi

    if ! mkdir -p -- "$state_dir" ||
      ! touch -- "$update_marker"; then
      LAST_ERROR="Failed to record the initial system update"
      return 1
    fi
  fi
}

install_aur_helper() {
  LAST_ERROR=""

  if ! pacman -Q base-devel >/dev/null 2>&1; then
    log STEP "Installing AUR build prerequisites"

    if ! sudo pacman -S --needed --noconfirm base-devel; then
      LAST_ERROR="Failed to install AUR build prerequisites"
      return 1
    fi
  fi

  if command_exists "$CHAOTIC_AUR_HELPER" || command_exists paru; then
    return 0
  fi

  log STEP "Installing $CHAOTIC_AUR_HELPER from Chaotic-AUR"

  if sudo pacman -S --needed --noconfirm \
    "$CHAOTIC_AUR_REPO/$CHAOTIC_AUR_HELPER"; then
    return 0
  fi

  LAST_ERROR="Failed to install $CHAOTIC_AUR_HELPER"
  return 1
}
