#!/usr/bin/env bash
# 08_wallpapers.sh - Download and install wallpapers
#
# Downloads wallpapers from GitHub releases and extracts them to ~/Pictures/Wallpapers.
# Skips download if wallpapers directory already exists and contains files.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   HOME - User home directory
#   CHEZMOI_SOURCE_DIR - Chezmoi source directory (set by chezmoi)
# Exit codes:
#   0 (success), 1 (failure), 127 (missing dependency)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"

readonly WALLPAPERS_DIR="${HOME}/Pictures/Wallpapers"
readonly WALLPAPERS_URL="https://github.com/vantesh/wallpapers/releases/latest/download/wallpapers.zip"

cleanup() {
  if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT INT TERM

download_wallpapers() {
  LAST_ERROR=""

  if ! command_exists curl; then
    LAST_ERROR="curl is required to download wallpapers"
    return 127
  fi

  if ! command_exists unzip; then
    LAST_ERROR="unzip is required to extract wallpapers"
    return 127
  fi

  TEMP_DIR="$(mktemp -d)"
  readonly TEMP_ZIP="$TEMP_DIR/wallpapers.zip"

  if ! curl -fsSL -o "$TEMP_ZIP" "$WALLPAPERS_URL" 2>/dev/null; then
    LAST_ERROR="Failed to download wallpapers from $WALLPAPERS_URL"
    return 1
  fi

  if ! mkdir -p "$WALLPAPERS_DIR"; then
    LAST_ERROR="Failed to create wallpapers directory: $WALLPAPERS_DIR"
    return 1
  fi

  if ! unzip -q -o "$TEMP_ZIP" -d "$TEMP_DIR" 2>/dev/null; then
    LAST_ERROR="Failed to extract wallpapers archive"
    return 1
  fi

  local extracted_dir
  extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d ! -path "$TEMP_DIR" -print -quit)

  if [[ -n "$extracted_dir" ]]; then
    if ! cp -r "$extracted_dir"/* "$WALLPAPERS_DIR/" 2>/dev/null; then
      LAST_ERROR="Failed to copy wallpapers to destination"
      return 1
    fi
  else
    if ! cp -r "$TEMP_DIR"/*.{jpg,jpeg,png,webp} "$WALLPAPERS_DIR/" 2>/dev/null; then
      LAST_ERROR="No wallpapers found in archive"
      return 1
    fi
  fi

  return 0
}

main() {
  if [[ -d "$WALLPAPERS_DIR" ]] && [[ -n "$(ls -A "$WALLPAPERS_DIR" 2>/dev/null)" ]]; then
    log SKIP "Wallpapers already installed"
    exit 0
  fi

  print_box "Wallpapers"
  log STEP "Installing Wallpapers"

  if download_wallpapers; then
    log INFO "Installed wallpapers to $WALLPAPERS_DIR"
  else
    log WARN "Failed to install wallpapers: $LAST_ERROR"
  fi

}

main "$@"
