#!/usr/bin/env bash
set -euo pipefail

main() {
  if ! command -v fish >/dev/null 2>&1; then
    echo "fish not found" >&2
    return 127
  fi

  local fzf_script="$HOME/.cache/wal/fzf.fish"
  local fish_cmd="yes | fish_config theme save Matugen"

  if [[ -f "$fzf_script" ]]; then
    fish_cmd="${fish_cmd}; and source '${fzf_script}'"
  fi

  if ! fish -c "$fish_cmd" >/dev/null 2>&1; then
    echo "Failed to configure Fish theme" >&2
    return 1
  fi

  return 0
}

main "$@"
