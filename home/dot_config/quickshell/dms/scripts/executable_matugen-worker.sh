#!/usr/bin/env bash

mode=$(qs -c dms ipc call theme getMode)
wallpaper=$(qs -c dms ipc call wallpaper get)

# Ensure local bin is in PATH for walset to be found
export PATH="$HOME/.local/bin:$PATH"

# Run walset script
walset "$wallpaper" --mode "$mode"
