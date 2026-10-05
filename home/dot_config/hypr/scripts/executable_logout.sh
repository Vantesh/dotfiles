#!/usr/bin/env bash
# Stop the UWSM session, or terminate the user session when not using UWSM.

set -euo pipefail


if env | grep -q '^UWSM_'; then
  exec uwsm stop
else
  exec loginctl terminate-session "$XDG_SESSION_ID"
fi
