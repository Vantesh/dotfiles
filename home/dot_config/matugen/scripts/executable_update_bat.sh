#!/usr/bin/env bash
set -euo pipefail

main() {
  if ! command_exists bat; then
    return 0
  fi

  log "INFO" "Refreshing bat syntax cache"
  if ! bat cache --build >/dev/null 2>&1; then
    log "WARN" "bat cache refresh completed with warnings"
  fi
}

main "$@"
