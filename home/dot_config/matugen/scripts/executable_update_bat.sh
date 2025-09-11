#!/usr/bin/env bash
set -euo pipefail

if command -v bat &>/dev/null; then
  echo "Info: Updating bat syntax cache"
  bat cache --build >/dev/null 2>&1 || true
fi
