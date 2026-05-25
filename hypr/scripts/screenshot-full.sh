#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/screenshot-utils.sh"

main() {
  ensure_dependencies grim wl-copy
  ensure_save_dir

  local output
  output="$(timestamp_path full)"

  if ! capture_full "$output"; then
    notify_error "Screenshot gagal" "Capture full screen dibatalkan atau gagal."
    exit 1
  fi

  finish_capture "$output" "Full screenshot"
}

main "$@"
