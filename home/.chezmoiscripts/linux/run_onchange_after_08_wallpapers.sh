#!/usr/bin/env bash
# 08_wallpapers.sh - Download and install wallpapers
#
# Downloads random wallpapers from 4kwallpapers.com to ~/Pictures/Wallpapers.
# Skips download if the wallpapers directory already contains ten files.
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
readonly WALLPAPERS_URL="https://4kwallpapers.com/random-wallpapers/"
readonly WALLPAPER_BASE_URL="https://4kwallpapers.com"
readonly WALLPAPER_IMAGE_PATH="/images/wallpapers/"
readonly WALLPAPER_COUNT=10

cleanup() {
  if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT ERR INT TERM

download_wallpapers() {
  LAST_ERROR=""

  if ! command_exists curl; then
    LAST_ERROR="curl is required to download wallpapers"
    return 127
  fi

  TEMP_DIR="$(mktemp -d)"
  readonly WALLPAPER_HTML="$TEMP_DIR/wallpapers.html"

  if ! mkdir -p "$WALLPAPERS_DIR"; then
    LAST_ERROR="Failed to create wallpapers directory: $WALLPAPERS_DIR"
    return 1
  fi

  if ! curl -fsSL --max-time 30 -o "$WALLPAPER_HTML" "$WALLPAPERS_URL" 2>/dev/null; then
    LAST_ERROR="Failed to download wallpapers from $WALLPAPERS_URL"
    return 1
  fi

  local downloaded_count
  downloaded_count=0
  while read -r wallpaper_page; do
    [[ "$downloaded_count" -ge "$WALLPAPER_COUNT" ]] && break

    local page_html image_pattern image_url image_name page_url
    page_url="https://4kwallpapers.com$wallpaper_page"
    if ! page_html="$(curl -fsSL --max-time 30 "$page_url" 2>/dev/null)"; then
      continue
    fi

    image_pattern="${WALLPAPER_IMAGE_PATH}[^\" ]+\.(jpg|jpeg|png|webp)"
    image_url="$(printf '%s' "$page_html" | grep -oE "$image_pattern" | head -n 1)"
    [[ -z "$image_url" ]] && continue

    image_name="$(basename "$image_url")"
    if curl -fsSL --max-time 60 -o "$WALLPAPERS_DIR/$image_name" "$WALLPAPER_BASE_URL$image_url" 2>/dev/null; then
      downloaded_count=$((downloaded_count + 1))
    else
      rm -f -- "$WALLPAPERS_DIR/$image_name"
    fi
  done < <(grep -oE '(https://4kwallpapers\.com)?/[^" ]+\.html' "$WALLPAPER_HTML" | sort -u)

  if [[ "$downloaded_count" -lt "$WALLPAPER_COUNT" ]]; then
    LAST_ERROR="Downloaded $downloaded_count of $WALLPAPER_COUNT wallpapers"
    return 1
  fi

  return 0
}

main() {
  if [[ -d "$WALLPAPERS_DIR" ]] && [[ "$(find "$WALLPAPERS_DIR" -maxdepth 1 -type f | wc -l)" -ge "$WALLPAPER_COUNT" ]]; then
    log SKIP "Wallpapers already installed"
    exit 0
  fi

  log STEP "Installing Wallpapers"

  if download_wallpapers; then
    log INFO "Installed wallpapers to $WALLPAPERS_DIR"
  else
    log WARN "Failed to install wallpapers: $LAST_ERROR"
  fi

}

main "$@"
