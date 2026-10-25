#!/usr/bin/env bash
# Establish the packaged Python runtime before importing the bootstrap.
set -euo pipefail

missing=()
for package in python python-loguru; do
  pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  printf '%(%H:%M:%S)T | INFO    | Installing Python bootstrap dependencies\n' -1 >&2
  sudo pacman -S --needed --noconfirm -- "${missing[@]}"
fi

exec /usr/bin/python3 -B "${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoitemplates/bootstrap.py"
