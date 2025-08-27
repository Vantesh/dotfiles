#!/usr/bin/env bash

# Get mode and wallpaper from QuickShell IPC
mode=$(qs -c dms ipc call theme getMode)
wallpaper=$(qs -c dms ipc call wallpaper get)

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

# Run walset and propagate its exit code
walset "$wallpaper" --mode "$mode"
exit_code=$?
exit $exit_code
