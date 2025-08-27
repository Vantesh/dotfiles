#!/usr/bin/env bash

mode="${MODE:-dark}"

if command -v python3 &>/dev/null; then
  SCRIPT="$HOME/.config/matugen/scripts/dank16.py"
  LIGHT_ARG=""
  if [ "$mode" = "light" ]; then
    LIGHT_ARG="--light"
  fi
  python3 "$SCRIPT" $LIGHT_ARG >"$HOME/.config/kitty/dank16.conf"
fi

if command -v kitty &>/dev/null; then
  kitty +kitten themes --reload-in=all matugen &>/dev/null || true
fi

if command -v fish &>/dev/null; then
  {
    fish -c "yes | fish_config theme save Matugen" 2>/dev/null
    [[ -f "$HOME/.cache/wal/fzf.fish" ]] && fish "$HOME/.cache/wal/fzf.fish" 2>/dev/null
  } || true
fi
