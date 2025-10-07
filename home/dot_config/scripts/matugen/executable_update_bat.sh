#!/usr/bin/env bash
# update_bat.sh - Refresh bat syntax cache with current theme
# Exit codes: 0 (success), 1 (failure)

set -euo pipefail

main() {
  if ! command_exists bat; then
    return 0
  fi

  log INFO "Refreshing bat syntax cache"

  if ! bat cache --build >/dev/null 2>&1; then
    log WARN "bat cache refresh completed with warnings"
    return 1
  fi

  return 0
}

main "$@"
