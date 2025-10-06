#!/usr/bin/env bash
# 07_miscellaneous.sh - Miscellaneous system configurations
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly SSH_KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
readonly SPOTIFY_PREFS="${HOME}/.config/spotify/prefs"

if ! keep_sudo_alive; then
  die "Failed to keep sudo alive"
fi

setup_pkgfile() {
  if ! command_exists pacman; then
    return 0
  fi

  if ! command_exists pkgfile; then
    log SKIP "pkgfile not installed"
    return 0
  fi

  if sudo systemctl is-enabled pkgfile-update.timer >/dev/null 2>&1; then
    log SKIP "pkgfile-update.timer already enabled"
    return 0
  fi

  if ! sudo pkgfile --update >/dev/null 2>&1; then
    LAST_ERROR="Failed to update pkgfile database"
    return 1
  fi

  if ! enable_service "pkgfile-update.timer" "system"; then
    LAST_ERROR="Failed to enable pkgfile-update.timer: $LAST_ERROR"
    return 1
  fi

  log INFO "Updated pkgfile database and enabled timer"
  return 0
}

regenerate_font_cache() {
  if ! fc-cache -f -v >/dev/null 2>&1; then
    LAST_ERROR="Failed to regenerate font cache"
    return 1
  fi

  log INFO "Regenerated font cache"
  return 0
}

setup_ssh_known_hosts() {
  if [[ ! -f "$SSH_KNOWN_HOSTS" ]]; then
    if ! touch "$SSH_KNOWN_HOSTS"; then
      LAST_ERROR="Failed to create known_hosts file"
      return 1
    fi

    if ! chmod 644 "$SSH_KNOWN_HOSTS"; then
      LAST_ERROR="Failed to set permissions on known_hosts"
      return 1
    fi

    log INFO "Created SSH known_hosts file"
  fi

  local added=false

  if ! grep -q "github.com" "$SSH_KNOWN_HOSTS"; then
    if ssh-keyscan github.com >>"$SSH_KNOWN_HOSTS" 2>/dev/null; then
      log INFO "Added GitHub to known_hosts"
      added=true
    else
      log WARN "Failed to add GitHub to known_hosts"
    fi
  fi

  if ! grep -q "gitlab.com" "$SSH_KNOWN_HOSTS"; then
    if ssh-keyscan gitlab.com >>"$SSH_KNOWN_HOSTS" 2>/dev/null; then
      log INFO "Added GitLab to known_hosts"
      added=true
    else
      log WARN "Failed to add GitLab to known_hosts"
    fi
  fi

  if [[ "$added" == false ]] && [[ -f "$SSH_KNOWN_HOSTS" ]]; then
    log SKIP "SSH known_hosts already configured"
  fi

  return 0
}

setup_spicetify() {
  if ! command_exists spotify && ! command_exists spotify-launcher; then
    log SKIP "Spotify not installed"
    return 0
  fi

  if ! command_exists spicetify; then
    log SKIP "Spicetify not installed"
    return 0
  fi

  if [[ ! -f "$SPOTIFY_PREFS" ]]; then
    local spotify_dir
    spotify_dir=$(dirname "$SPOTIFY_PREFS")

    if ! mkdir -p "$spotify_dir"; then
      LAST_ERROR="Failed to create spotify config directory"
      return 1
    fi

    if ! touch "$SPOTIFY_PREFS"; then
      LAST_ERROR="Failed to create spotify prefs file"
      return 1
    fi
  fi

  if ! spicetify backup apply >/dev/null 2>&1; then
    LAST_ERROR="Failed to apply spicetify theme"
    return 1
  fi

  log INFO "Applied spicetify theme"
  return 0
}

install_yazi_plugins() {
  if ! command_exists yazi; then
    log SKIP "Yazi not installed"
    return 0
  fi

  if ! ya pkg install >/dev/null 2>&1; then
    LAST_ERROR="Failed to install Yazi plugins"
    return 1
  fi

  log INFO "Installed Yazi plugins"
  return 0
}

set_time_locale() {
  local current_lc_time
  current_lc_time=$(localectl status | grep -oP 'LC_TIME=\K[^ ]+' || true)

  if [[ "$current_lc_time" == "en_ZA.UTF-8" ]]; then
    log SKIP "LC_TIME already set to en_ZA.UTF-8"
    return 0
  fi

  if ! sudo localectl set-locale LC_TIME=en_ZA.UTF-8 >/dev/null 2>&1; then
    LAST_ERROR="Failed to set LC_TIME locale"
    return 1
  fi

  log INFO "Set LC_TIME to en_ZA.UTF-8 (24-hour format)"
  return 0
}

main() {
  print_box "Miscellaneous"
  log STEP "Miscellaneous Configuration"

  if ! setup_pkgfile; then
    log WARN "pkgfile setup failed: $LAST_ERROR"
  fi

  if ! regenerate_font_cache; then
    log WARN "Font cache regeneration failed: $LAST_ERROR"
  fi

  if ! setup_ssh_known_hosts; then
    log WARN "SSH known_hosts setup failed: $LAST_ERROR"
  fi

  if ! setup_spicetify; then
    log WARN "Spicetify setup failed: $LAST_ERROR"
  fi

  if ! install_yazi_plugins; then
    log WARN "Yazi plugin installation failed: $LAST_ERROR"
  fi

  if ! set_time_locale; then
    log WARN "Time locale configuration failed: $LAST_ERROR"
  fi

  log INFO "Miscellaneous configuration complete"
}

main "$@"
