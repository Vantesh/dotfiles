#!/usr/bin/env bash
set -euo pipefail

readonly THEME_GENERATOR="$HOME/.config/matugen/scripts/dank16.py"
readonly KITTY_CONFIG_DIR="$HOME/.config/kitty"
readonly GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
readonly KITTY_THEME_FILE="$KITTY_CONFIG_DIR/dank16.conf"
readonly GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/themes/Matugen"

determine_mode() {
  local mode="${MODE:-dark}"

  case "$mode" in
  light | dark)
    printf '%s\n' "$mode"
    ;;
  *)
    log "WARN" "Invalid MODE='$mode'; defaulting to dark"
    printf 'dark\n'
    ;;
  esac
}

apply_kitty_theme() {
  local mode="$1"

  if ! command_exists kitty; then
    return 0
  fi

  ensure_directory "$KITTY_CONFIG_DIR"
  if python3 "$THEME_GENERATOR" --"$mode" >"$KITTY_THEME_FILE"; then
    send_signal_if_running "USR1" "kitty"
  else
    log "WARN" "Failed to generate kitty theme"
  fi
}

apply_ghostty_theme() {
  local mode="$1"

  if ! command_exists ghostty; then
    return 0
  fi

  ensure_directory "$GHOSTTY_CONFIG_DIR/themes"
  if ! python3 "$THEME_GENERATOR" --"$mode" --ghostty >"$GHOSTTY_THEME_FILE"; then
    log "WARN" "Failed to generate Ghostty theme"
  fi

  local config_file="$GHOSTTY_CONFIG_DIR/config"
  set_config_value "$config_file" "theme" '=' "Matugen"
  set_config_value "$config_file" "app-notifications" '=' "no-clipboard-copy,no-config-reload"
  send_signal_if_running "USR2" "ghostty"
}

apply_fish_theme() {
  local fzf_script="$HOME/.cache/wal/fzf.fish"

  if ! command_exists fish; then
    return 0
  fi

  if ! fish -c "yes | fish_config theme save Matugen"; then
    log "WARN" "Failed to update fish theme via fish_config"
  fi

  if [[ -f "$fzf_script" ]]; then
    if ! fish "$fzf_script" >/dev/null 2>&1; then
      log "WARN" "Failed to run fzf theme helper at $fzf_script"
    fi
  fi
}

main() {
  if [[ ! -f "$THEME_GENERATOR" ]]; then
    log "ERROR" "Missing theme generator: $THEME_GENERATOR"
    return 1
  fi

  require_command python3 || return 1

  local mode
  mode=$(determine_mode)

  apply_kitty_theme "$mode"
  apply_ghostty_theme "$mode"
  apply_fish_theme
}

main "$@"
