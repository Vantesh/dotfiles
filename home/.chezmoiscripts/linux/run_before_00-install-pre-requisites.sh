#!/usr/bin/env bash
# Establish all runtime and package prerequisites before Python provisioning starts.
set -o errexit -o nounset -o pipefail

packages=(python python-loguru git base-devel mise)
if [[ "${DOTFILES_PERSONAL_ENABLED:-0}" == "1" ]]; then
  packages+=(rbw pinentry)
fi
missing=()
for package in "${packages[@]}"; do
  pacman --query "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  printf '[%(%Y-%m-%d %H:%M:%S)T] [INFO] Installing bootstrap dependencies\n' -1 >&2
  sudo pacman --sync --needed --noconfirm -- "${missing[@]}"
fi
