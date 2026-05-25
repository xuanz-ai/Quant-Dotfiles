#!/usr/bin/env bash
set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
  exit 0
fi

if ! pgrep -f "wl-paste --type text --watch cliphist store" >/dev/null 2>&1; then
  wl-paste --type text --watch cliphist store >/tmp/cliphist-text.log 2>&1 &
fi

if ! pgrep -f "wl-paste --type image --watch cliphist store" >/dev/null 2>&1; then
  wl-paste --type image --watch cliphist store >/tmp/cliphist-image.log 2>&1 &
fi
