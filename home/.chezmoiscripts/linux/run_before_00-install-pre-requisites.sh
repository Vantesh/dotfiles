#!/usr/bin/env bash
# Establish all runtime and package prerequisites before Python provisioning starts.
set -euo pipefail

packages=(python python-loguru git base-devel mise)
if [[ "${PERSONAL:-0}" == "1" ]]; then
  packages+=(rbw pinentry)
fi
missing=()
for package in "${packages[@]}"; do
  pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  printf '[%(%Y-%m-%d %H:%M:%S)T] [INFO] Installing bootstrap dependencies\n' -1 >&2
  sudo pacman -S --needed --noconfirm -- "${missing[@]}"
fi

exec /usr/bin/python3 -B "${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoitemplates/bootstrap.py"
