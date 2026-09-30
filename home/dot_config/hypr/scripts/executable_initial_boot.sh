#!/usr/bin/env bash
# initial_boot - First-boot setup: set a random wallpaper through dms.
# Exit codes: 0 (success or nothing to do), 1 (failure; will retry next start)

set -euo pipefail

readonly STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly SENTINEL="$STATE_BASE/hypr/first_setup_done"
readonly LEGACY_SENTINEL="$STATE_BASE/${XDG_CURRENT_DESKTOP:-unknown}/first_setup_done"

readonly WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
readonly MAX_ATTEMPTS=10
readonly RETRY_DELAY=1

log() {
    logger -t initial_boot -- "$*" 2>/dev/null || true
}

notify() { # notify <icon> <title> <body>
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --icon="$1" "$2" "$3" || true
    fi
}

pick_wallpaper() {
    local wp=""
    IFS= read -r -d '' wp < <(
        find -L "$WALLPAPER_DIR" -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
            -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' -o \
            -iname '*.gif' -o -iname '*.jxl' \
        \) -print0 2>/dev/null | shuf -z -n 1
    ) || true
    printf '%s' "$wp"
}

# Retry until dms is up and accepts the command
set_wallpaper() {
    local wp=$1 attempt
    for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
        if dms ipc call wallpaper set "$wp" >/dev/null 2>&1; then
            log "wallpaper set on attempt $attempt: $wp"
            return 0
        fi
        sleep "$RETRY_DELAY"
    done
    return 1
}

main() {
    if [[ -f $SENTINEL || -f $LEGACY_SENTINEL ]]; then
        return 0
    fi

    # dms not installed (yet): do nothing, and try again on a later start.
    if ! command -v dms >/dev/null 2>&1; then
        log "dms not found, skipping"
        return 0
    fi

    local wallpaper
    wallpaper="$(pick_wallpaper)"
    if [[ -z $wallpaper ]]; then
        log "no images in $WALLPAPER_DIR"
        notify dialog-error "Wallpaper" "No images found in $WALLPAPER_DIR. Add one and restart Hyprland."
        return 1
    fi

    if ! set_wallpaper "$wallpaper"; then
        log "dms did not accept the wallpaper after $MAX_ATTEMPTS attempts"
        notify dialog-error "Wallpaper" "Could not set a wallpaper (is dms running?). Will retry next start."
        return 1
    fi

    # Only mark setup done after the wallpaper was actually applied.
    mkdir -p "$(dirname "$SENTINEL")"
    printf '# DO NOT DELETE THIS FILE\n# This file indicates the first setup has been completed.\n' >"$SENTINEL"

    notify nwg-look "Welcome" "First setup completed successfully! Enjoy your Hyprland experience."
    return 0
}

main "$@"
