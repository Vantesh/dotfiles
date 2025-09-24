#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dark}"
readonly MODE

case "$MODE" in
light | dark) ;;
*)
  printf 'Warning: invalid MODE="%s", falling back to dark\n' "$MODE" >&2
  MODE="dark"
  ;;
esac

readonly SCRIPT="$HOME/.config/matugen/scripts/dank16.py"
readonly KITTY_CONFIG_DIR="$HOME/.config/kitty"
readonly GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
readonly KITTY_THEME_FILE="$KITTY_CONFIG_DIR/dank16.conf"
readonly GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/themes/Matugen"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_directory() {
  mkdir -p "$1"
}

ensure_config_kv() {
  local key="$1"
  local value="$2"
  local file="$3"

  if grep -q "^${key} =" "$file"; then
    sed -i "s|^${key} = .*|${key} = ${value}|" "$file"
  else
    printf '%s = %s\n' "$key" "$value" >>"$file"
  fi
}

# =============================================================================
# Kitty
# =============================================================================
apply_kitty_theme() {
  if ! command_exists "kitty"; then
    return
  fi

  ensure_directory "$KITTY_CONFIG_DIR"
  python3 "$SCRIPT" --"$MODE" >"$KITTY_THEME_FILE"

  kitty +kitten themes --reload-in=all matugen || true
}

# =============================================================================
# Ghostty
# =============================================================================
apply_ghostty_theme() {
  if ! command_exists "ghostty"; then
    return
  fi

  ensure_directory "$GHOSTTY_CONFIG_DIR"
  ensure_directory "$GHOSTTY_CONFIG_DIR/themes"
  python3 "$SCRIPT" --"$MODE" --ghostty >"$GHOSTTY_THEME_FILE"

  local config_file="$GHOSTTY_CONFIG_DIR/config"
  [[ -f "$config_file" ]] || : >"$config_file"

  ensure_config_kv "theme" "Matugen" "$config_file"
  ensure_config_kv "app-notifications" "no-clipboard-copy,no-config-reload" "$config_file"

  if pgrep -x ghostty &>/dev/null; then
    pkill -USR2 -x ghostty
  fi
}

# =============================================================================
# Fish Theme
# =============================================================================
apply_fish_theme() {
  if ! command_exists "fish"; then
    return
  fi

  local fzf_script="$HOME/.cache/wal/fzf.fish"
  {
    fish -c "yes | fish_config theme save Matugen" 2>/dev/null
    [[ -f "$fzf_script" ]] && fish "$fzf_script" 2>/dev/null
  } || true
}

# =============================================================================
# Main
# =============================================================================
main() {
  if [[ ! -f "$SCRIPT" ]]; then
    printf '%s\n' "Missing theme generator: $SCRIPT" >&2
    exit 1
  fi
  apply_kitty_theme
  apply_ghostty_theme
  apply_fish_theme
}

main "$@"
