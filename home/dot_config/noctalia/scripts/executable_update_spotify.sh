#!/usr/bin/env bash
# update_spotify.sh - Apply spicetify theme for Spotify customization
# Reloads the theme in a running Spotify WITHOUT restarting it (music keeps playing).
# Exit codes: 0 (success), 1 (failure)
#
# For instant hot reload, Spotify must be launched with a debug port, e.g.:
#   spotify --remote-debugging-port=9222
# (Spotify only accepts this flag at launch time.) Without it the theme files are
# still updated, but you need to reload the window yourself (Ctrl+Shift+R, needs
# `spicetify enable-devtools` once) or restart Spotify.

set -euo pipefail

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"

log() {
  local level="${1:-}"
  shift || true
  local message="$*"
  case "${level^^}" in
  INFO) printf '  %bINFO%b  %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$message" >&2 ;;
  WARN) printf '  %bWARN%b  %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$message" >&2 ;;
  ERROR) printf '  %bERROR%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$message" >&2 ;;
  SKIP) printf '  %bSKIP%b  %s\n' "\033[1;35m" "$COLOR_RESET" "$message" >&2 ;;
  *) printf '%s\n' "$message" >&2 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

readonly DESIRED_SPICETIFY_THEME="Sleek"
readonly SPOTIFY_DEBUG_PORT="${SPOTIFY_DEBUG_PORT:-9222}"

# ensure_spicetify_theme configures spicetify theme if not already set
# Returns: 0 on success/already set, 1 on failure
ensure_spicetify_theme() {
  local current
  current=$(spicetify config current_theme 2>/dev/null | tr -d "[:space:]'" || true)

  if [[ "$current" == "$DESIRED_SPICETIFY_THEME" ]]; then
    log SKIP "Spicetify theme already set to $DESIRED_SPICETIFY_THEME"
    return 0
  fi

  if spicetify config current_theme "$DESIRED_SPICETIFY_THEME" >/dev/null 2>&1; then
    log INFO "Configured spicetify theme: $DESIRED_SPICETIFY_THEME"
    return 0
  fi

  log ERROR "Unable to configure spicetify theme to $DESIRED_SPICETIFY_THEME (start spotify and run 'spicetify backup apply' if this is the first time)"
  return 1
}

# write_theme_files updates the theme files on disk without restarting Spotify.
# Tries a cheap refresh first, then falls back to apply --no-restart.
# Returns: 0 on success, 1 on failure
write_theme_files() {
  if spicetify -q refresh >/dev/null 2>&1; then
    log INFO "Refreshed spicetify theme files"
    return 0
  fi

  if spicetify -q apply --no-restart >/dev/null 2>&1; then
    log INFO "Applied spicetify theme (no restart)"
    return 0
  fi

  log WARN "spicetify could not apply the theme, try running 'spicetify backup apply' first"
  return 1
}

# reload_running_spotify reloads Spotify's UI over its Chromium debug port.
# Only reloads the web UI, so playback is not interrupted.
# Returns: 0 on success, 1 if the debug port is unavailable
reload_running_spotify() {
  command_exists python3 || return 1

  python3 - "$SPOTIFY_DEBUG_PORT" <<'PY' >/dev/null 2>&1
import base64, json, os, socket, struct, sys, urllib.request

port = int(sys.argv[1])
targets = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=2))
pages = [t for t in targets if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
pages = [t for t in pages if "xpui" in t.get("url", "")] or pages
if not pages:
    sys.exit(1)

path = "/" + pages[0]["webSocketDebuggerUrl"].split("/", 3)[3]
sock = socket.create_connection(("127.0.0.1", port), timeout=3)
key = base64.b64encode(os.urandom(16)).decode()
sock.sendall((
    f"GET {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n"
    f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
).encode())

resp = b""
while b"\r\n\r\n" not in resp:
    chunk = sock.recv(4096)
    if not chunk:
        sys.exit(1)
    resp += chunk
if b" 101 " not in resp.split(b"\r\n", 1)[0]:
    sys.exit(1)

payload = json.dumps({"id": 1, "method": "Page.reload", "params": {"ignoreCache": True}}).encode()
mask = os.urandom(4)
header = bytearray([0x81])
if len(payload) < 126:
    header.append(0x80 | len(payload))
else:
    header.append(0x80 | 126)
    header += struct.pack(">H", len(payload))
masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
sock.sendall(bytes(header) + mask + masked)
try:
    sock.recv(4096)
except OSError:
    pass
sock.close()
PY
}

main() {
  if ! command_exists spicetify; then
    log WARN "spicetify not found; skipping spotify update"
    return 0
  fi

  if ! ensure_spicetify_theme; then
    return 1
  fi

  if ! spicetify config color_scheme noctalia >/dev/null 2>&1; then
    log ERROR "Unable to configure spicetify color scheme to noctalia"
    return 1
  fi

  if ! write_theme_files; then
    return 1
  fi

  if pgrep -x spotify >/dev/null 2>&1; then
    if reload_running_spotify; then
      log INFO "Reloaded Spotify theme live"
    else
      log WARN "Theme updated, but Spotify has no debug port (${SPOTIFY_DEBUG_PORT}). Launch it with --remote-debugging-port=${SPOTIFY_DEBUG_PORT} for live reload, or press Ctrl+Shift+R in Spotify"
    fi
  fi

  return 0
}

main "$@"
