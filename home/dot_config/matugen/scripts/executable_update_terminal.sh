#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dark}"
SCRIPT="$HOME/.config/matugen/scripts/dank16.py"

KITTY_CONFIG_DIR="$HOME/.config/kitty"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
KITTY_THEME_FILE="$KITTY_CONFIG_DIR/themes/Matugen.conf"
GHOSTTY_THEME_FILE="$GHOSTTY_CONFIG_DIR/dank16.conf"

# =============================================================================
# Kitty
# =============================================================================
apply_kitty_theme() {
  if ! command -v kitty &>/dev/null; then
    return
  fi

  {
    echo ""
    echo "# Dank16 Colors"
    python3 "$SCRIPT" --"$MODE"
  } >>"$KITTY_THEME_FILE"

  kitty +kitten themes --reload-in=all matugen &>/dev/null || true
}

# =============================================================================
# Ghostty
# =============================================================================
apply_ghostty_theme() {
  if ! command -v ghostty &>/dev/null; then
    return
  fi

  mkdir -p "$GHOSTTY_CONFIG_DIR"
  python3 "$SCRIPT" --"$MODE" --ghostty >"$GHOSTTY_THEME_FILE"

  local config_file="$GHOSTTY_CONFIG_DIR/config"
  if ! grep -q "config-file = ./dank16.conf" "$config_file" 2>/dev/null; then
    echo "config-file = ./dank16.conf" >>"$config_file"
  fi

  # Reload Ghostty configs (simulate keypress since no auto-reload support)
  if pgrep -x ghostty &>/dev/null; then
    local ghostty_addresses
    ghostty_addresses=$(hyprctl clients -j | jq -r '.[] | select(.class == "com.mitchellh.ghostty") | .address')

    if [[ -n "$ghostty_addresses" ]]; then
      local current_window
      current_window=$(hyprctl activewindow -j | jq -r '.address')

      while IFS= read -r address; do
        hyprctl dispatch focuswindow "address:$address" >/dev/null || true
        sleep 0.1
        hyprctl dispatch sendshortcut "CTRL SHIFT, comma, address:$address" >/dev/null || true
      done <<<"$ghostty_addresses"

      [[ -n "$current_window" ]] && hyprctl dispatch focuswindow "address:$current_window" >/dev/null || true
    fi
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
apply_kitty_theme
apply_ghostty_theme
apply_fish_theme
exit 0
