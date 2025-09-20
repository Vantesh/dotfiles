#!/bin/sh
# Bootstrap script for chezmoi
# Backs up ~/.config once, then runs chezmoi init

set -e # Exit on error

# Install chezmoi if not found
if ! command -v chezmoi >/dev/null 2>&1; then
  bin_dir="$HOME/.local/bin"
  chezmoi="$bin_dir/chezmoi"
  if command -v curl >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif command -v wget >/dev/null 2>&1; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
else
  chezmoi="chezmoi"
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$STATE_DIR"
backup_marker="$STATE_DIR/config-backup-done"

# Backup ~/.config only once if not already done
if [ ! -f "$backup_marker" ]; then
  if [ -d "$HOME/.config" ]; then
    backup_dir="$HOME/.config.backup.$(date +%Y%m%d%H%M%S)"
    echo "Backing up ~/.config to $backup_dir"
    mv "$HOME/.config" "$backup_dir"
  fi
  touch "$backup_marker"
fi

# Get script dir (POSIX way)
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

# Run chezmoi init
exec "$chezmoi" init --apply "--source=$script_dir"
