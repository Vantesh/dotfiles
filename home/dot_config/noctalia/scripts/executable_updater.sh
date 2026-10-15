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
elif command -v yay >/dev/null 2>&1; then
  yay -Syu "$@"
else
  sudo pacman -Syu "$@"
fi

status=$?
if (( status == 0 )); then
  noctalia msg plugin yuuto/arch-updater:service all check
fi
exit "$status"
