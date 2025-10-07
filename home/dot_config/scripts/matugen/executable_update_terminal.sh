#!/usr/bin/env bash
# update_terminal.sh - Update terminal emulator themes (Kitty, Ghostty, Fish)
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

readonly THEME_GENERATOR="$SCRIPT_DIR/dank16.py"
readonly KITTY_CONFIG_DIR="$HOME/.config/kitty"
readonly GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
readonly KITTY_THEME_FILE="$KITTY_CONFIG_DIR/dank16.conf"
readonly GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/themes/Matugen"

main() {
  if [[ ! -f "$THEME_GENERATOR" ]]; then
    log ERROR "Missing theme generator: $THEME_GENERATOR"
    return 1
  fi

  if ! require_command python3; then
    log ERROR "python3 required but not found: $LAST_ERROR"
    return 127
  fi

  local mode="${MODE:-dark}"

  case "$mode" in
  light | dark) ;;
  *)
    log WARN "Invalid MODE='$mode'; defaulting to dark"
    mode="dark"
    ;;
  esac

  if command_exists kitty; then
    if ! ensure_directory "$KITTY_CONFIG_DIR"; then
      log ERROR "Failed to create Kitty config directory: $LAST_ERROR"
    elif ! python3 "$THEME_GENERATOR" --"$mode" >"$KITTY_THEME_FILE" 2>/dev/null; then
      log WARN "Failed to generate kitty theme"
    else
      send_signal_if_running USR1 kitty || log WARN "Failed to signal Kitty: $LAST_ERROR"
    fi
  fi

  if command_exists ghostty; then
    if ! ensure_directory "$GHOSTTY_CONFIG_DIR/themes"; then
      log ERROR "Failed to create Ghostty themes directory: $LAST_ERROR"
    elif ! python3 "$THEME_GENERATOR" --"$mode" --ghostty >"$GHOSTTY_THEME_FILE" 2>/dev/null; then
      log WARN "Failed to generate Ghostty theme"
    else
      local config_file="$GHOSTTY_CONFIG_DIR/config"
      set_config_value "$config_file" "theme" '=' "Matugen" || log WARN "Failed to set Ghostty theme: $LAST_ERROR"
      set_config_value "$config_file" "app-notifications" '=' "no-clipboard-copy,no-config-reload" || log WARN "Failed to set Ghostty notifications: $LAST_ERROR"
      send_signal_if_running USR2 ghostty || log WARN "Failed to signal Ghostty: $LAST_ERROR"
    fi
  fi

  if command_exists fish; then
    local fzf_script="$HOME/.cache/wal/fzf.fish"
    local fish_cmd="yes | fish_config theme save Matugen"

    # Append fzf script sourcing if it exists
    if [[ -f "$fzf_script" ]]; then
      fish_cmd="${fish_cmd}; and source '${fzf_script}'"
    fi

    if ! fish -c "$fish_cmd" >/dev/null 2>&1; then
      log WARN "Failed to configure Fish theme"
    fi
  fi

  return 0
}

main "$@"
