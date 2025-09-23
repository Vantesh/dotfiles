#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dark}"
SCRIPT="$HOME/.config/matugen/scripts/dank16.py"

KITTY_CONFIG_DIR="$HOME/.config/kitty"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
KITTY_THEME_FILE="$KITTY_CONFIG_DIR/dank16.conf"
GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/themes/Matugen"

# =============================================================================
# Kitty
# =============================================================================
apply_kitty_theme() {
  if ! command -v kitty &>/dev/null; then
    return
  fi

  python3 "$SCRIPT" --"$MODE" >"$KITTY_THEME_FILE"

  kitty +kitten themes --reload-in=all matugen || true
}

# =============================================================================
# Ghostty
# =============================================================================
apply_ghostty_theme() {
  if ! command -v ghostty &>/dev/null; then
    return
  fi

  mkdir -p "$GHOSTTY_CONFIG_DIR/themes"
  python3 "$SCRIPT" --"$MODE" --ghostty >"$GHOSTTY_THEME_FILE"

  local config_file="$GHOSTTY_CONFIG_DIR/config"
  if [[ -f "$config_file" ]]; then
    if grep -q "^theme =" "$config_file"; then
      sed -i 's/^theme = .*/theme = Matugen/' "$config_file"
    else
      echo "theme = Matugen" >>"$config_file"
    fi
  else
    echo "theme = Matugen" >"$config_file"
  fi

  if pgrep -x ghostty &>/dev/null; then
    pkill -USR2 -x ghostty
  fi
}

# =============================================================================
# Fish Theme
# =============================================================================
apply_fish_theme() {
  if ! command -v fish &>/dev/null; then
    return
  fi

  {
    fish -c "yes | fish_config theme save Matugen" 2>/dev/null
    [[ -f "$HOME/.cache/wal/fzf.fish" ]] && fish "$HOME/.cache/wal/fzf.fish" 2>/dev/null
  } || true
}

# =============================================================================
# Main
# =============================================================================
main() {
  [[ ! -f "$SCRIPT" ]] && {
    echo "Missing theme generator: $SCRIPT" >&2
    exit 1
  }
  apply_kitty_theme
  apply_ghostty_theme
  apply_fish_theme
}

main "$@"
