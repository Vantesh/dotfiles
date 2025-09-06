#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 STATE_DIR SHELL_DIR --run" >&2
  exit 1
fi

STATE_DIR="$1"
SHELL_DIR="$2"

if [ ! -d "$STATE_DIR" ]; then
  echo "Error: STATE_DIR '$STATE_DIR' does not exist" >&2
  exit 1
fi

if [ ! -d "$SHELL_DIR" ]; then
  echo "Error: SHELL_DIR '$SHELL_DIR' does not exist" >&2
  exit 1
fi

shift 2 # Remove STATE_DIR and SHELL_DIR from arguments

if [[ "${1:-}" != "--run" ]]; then
  echo "usage: $0 STATE_DIR SHELL_DIR --run" >&2
  exit 1
fi

DESIRED_JSON="$STATE_DIR/matugen.desired.json"
mode=$(jq -r '.mode // empty' "$DESIRED_JSON")
kind=$(jq -r '.kind // empty' "$DESIRED_JSON")
value=$(jq -r '.value // empty' "$DESIRED_JSON")

# Map JSON -> expected variables for downstream tools
if [[ "$kind" == "image" ]]; then
  wallpaper="$value"
else
  # Not an image request; treat as not-found for this worker
  wallpaper=""
fi

# Ensure local bin is in PATH for walset to be found
export PATH="$HOME/.local/bin:$PATH"

# If no wallpaper path is available, exit with code 2 so the caller treats it as
# "wallpaper/color not found" (Theme.qml treats exit code 2 as expected/skip).

# Treat empty/null or unreadable wallpaper as 'not found' (exit 2)
if [[ -z "${wallpaper:-}" || "${wallpaper}" == "null" ]]; then
  exit 2
fi

if [[ ! -r "${wallpaper}" ]]; then
  # If the wallpaper path is not a readable file, return 2 to indicate skip
  exit 2
fi

# Run walset
walset "$wallpaper" --mode "$mode"
