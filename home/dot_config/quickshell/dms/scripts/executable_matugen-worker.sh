#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${1:-}"
SHELL_DIR="${2:-}"

die() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "matugen-worker" "$msg" -i error -u critical
  else
    echo "matugen-worker: $msg" >&2
  fi
  exit 1
}

if [[ $# -ne 3 || "$3" != "--run" ]]; then
  echo "Usage: $0 STATE_DIR SHELL_DIR --run" >&2
  exit 1
fi

[[ -d "$STATE_DIR" ]] || die "STATE_DIR '$STATE_DIR' does not exist"
[[ -d "$SHELL_DIR" ]] || die "SHELL_DIR '$SHELL_DIR' does not exist"

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
[[ -f "$DESIRED_JSON" ]] || exit 2

read -r mode kind value < <(jq -r '[.mode // empty, .kind // empty, .value // empty] | @tsv' "$DESIRED_JSON")

case "$kind" in
image)
  [[ -n "$value" && -r "$value" ]] || exit 2
  args=("image" "$value")
  ;;
hex)
  [[ -n "$value" ]] || exit 2
  args=("color" "$value")
  ;;
*)
  exit 2
  ;;
esac

command -v walset >/dev/null 2>&1 || die "'walset' not found. Ensure ~/.local/bin is in PATH."

if [[ "$mode" == "dark" || "$mode" == "light" ]]; then
  args+=(--mode "$mode")
fi

walset "${args[@]}"
