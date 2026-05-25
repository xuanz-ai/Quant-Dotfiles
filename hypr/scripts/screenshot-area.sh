#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/screenshot-utils.sh"

main() {
  ensure_dependencies grim slurp wl-copy
  ensure_save_dir

  local geometry output
  output="$(timestamp_path area)"

  start_freeze
  trap stop_freeze EXIT

  if ! geometry="$(slurp -d -b 00000066 -c 89b4faff -s 89b4fa33 -B 1e1e2ecc -w 2)"; then
    notify_error "Screenshot dibatalkan" "Tidak ada area yang dipilih."
    exit 1
  fi

  stop_freeze
  trap - EXIT

  if [[ -z "$geometry" ]]; then
    notify_error "Screenshot dibatalkan" "Tidak ada area yang dipilih."
    exit 1
  fi

  if ! capture_geometry "$geometry" "$output"; then
    notify_error "Screenshot gagal" "Capture area gagal."
    exit 1
  fi

  finish_capture "$output" "Area screenshot"
}

main "$@"
