#!/usr/bin/env bash

  if command -v kitty &>/dev/null; then
    kitty +kitten themes --reload-in=all matugen &>/dev/null || true
  fi

  if command -v fish &>/dev/null; then
    {
      fish -c "yes | fish_config theme save Matugen" 2>/dev/null
      [[ -f "$HOME/.cache/wal/fzf.fish" ]] && fish "$HOME/.cache/wal/fzf.fish" 2>/dev/null
    } || true
  fi
