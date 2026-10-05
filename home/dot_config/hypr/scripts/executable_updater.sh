#!/usr/bin/env bash

echo '
               __     __
 __ _____  ___/ /__ _/ /____ ___
/ // / _ \/ _  / _ `/ __/ -_|_-<
\_,_/ .__/\_,_/\_,_/\__/\__/___/
   /_/
    '

if command -v topgrade >/dev/null 2>&1; then
  topgrade -k --no-self-update --skip-notify "$@"
elif command -v paru >/dev/null 2>&1; then
  paru -Syu "$@"
else
  sudo pacman -Syu "$@"
fi
