#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/screenshot-utils.sh"

SCREENSHOT_MENU_THEME="${SCREENSHOT_MENU_THEME:-$HOME/.config/rofi/themes/screenshot.rasi}"

screenshot_menu() {
  if [[ -f "$SCREENSHOT_MENU_THEME" ]]; then
    rofi -dmenu -i -p "Screenshot" -theme "$SCREENSHOT_MENU_THEME"
  else
    rofi_dmenu "Screenshot"
  fi
}

main() {
  ensure_dependencies rofi

  local choice
  if ! choice="$(
    printf '%s\n' "󰍹  Full Screen" "󰖲  Window Only" "󰩭  Select Screen" |
      screenshot_menu
  )"; then
    notify_error "Screenshot dibatalkan" "Menu ditutup tanpa pilihan."
    exit 1
  fi

  case "$choice" in
    *"Full Screen")
      exec "$SCRIPT_DIR/screenshot-full.sh"
      ;;
    *"Window Only")
      exec "$SCRIPT_DIR/screenshot-window.sh"
      ;;
    *"Select Screen")
      exec "$SCRIPT_DIR/screenshot-area.sh"
      ;;
    "")
      notify_error "Screenshot dibatalkan" "Menu ditutup tanpa pilihan."
      exit 1
      ;;
    *)
      notify_error "Screenshot gagal" "Pilihan tidak dikenal: $choice"
      exit 1
      ;;
  esac
}

main "$@"
