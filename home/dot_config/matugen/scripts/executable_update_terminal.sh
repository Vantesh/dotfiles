#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dark}"
SCRIPT="$HOME/.config/matugen/scripts/dank16.py"

KITTY_CONFIG_DIR="$HOME/.config/kitty"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
KITTY_THEME_FILE="$KITTY_CONFIG_DIR/themes/Matugen.conf"
GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/dank16.conf"

# Generate Kitty theme if kitty is available
if command -v kitty &>/dev/null; then
  {
    echo ""
    python3 "$SCRIPT" --"$MODE"
  } >>"$KITTY_THEME_FILE"

  kitty +kitten themes --reload-in=all matugen &>/dev/null || true
fi

if command -v ghostty &>/dev/null; then
  mkdir -p "$GHOSTTY_CONFIG_DIR"

  python3 "$SCRIPT" --"$MODE" --ghostty >"$GHOSTTY_THEME_FILE"

  if ! grep -q "config-file = ./dank16.conf" "$GHOSTTY_CONFIG_DIR/config"; then
    echo "config-file = ./dank16.conf" >>"$GHOSTTY_CONFIG_DIR/config"
  fi
fi

# Apply Fish shell theme if available
if command -v fish &>/dev/null; then
  {
    fish -c "yes | fish_config theme save Matugen" 2>/dev/null
    [[ -f "$HOME/.cache/wal/fzf.fish" ]] && fish "$HOME/.cache/wal/fzf.fish" 2>/dev/null
  } || true
fi
