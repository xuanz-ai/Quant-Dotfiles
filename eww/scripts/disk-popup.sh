#!/usr/bin/env bash

set -euo pipefail

EWW_CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww}"
EWW_DISK_CODE_DIR="${EWW_DISK_CODE_DIR:-$HOME/Code}"

toggle_popup() {
  if ! eww --config "$EWW_CONFIG_DIR" open --toggle disk_popup >/dev/null 2>&1; then
    eww --config "$EWW_CONFIG_DIR" daemon >/dev/null 2>&1
    eww --config "$EWW_CONFIG_DIR" open --toggle disk_popup >/dev/null 2>&1
  fi
}

open_folder() {
  local target

  case "${1:-}" in
    documents) target="$HOME/Documents" ;;
    downloads) target="$HOME/Downloads" ;;
    music) target="$HOME/Music" ;;
    pictures) target="$HOME/Pictures" ;;
    config) target="$HOME/.config" ;;
    code) target="$EWW_DISK_CODE_DIR" ;;
    *) exit 2 ;;
  esac

  mkdir -p "$target"
  eww --config "$EWW_CONFIG_DIR" close disk_popup >/dev/null 2>&1 || true
  xdg-open "$target" >/dev/null 2>&1 &
}

case "${1:-toggle}" in
  toggle) toggle_popup ;;
  open) open_folder "${2:-}" ;;
  *) exit 2 ;;
esac
