#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/screenshot-utils.sh"

WINDOW_THUMB_DIR="${WINDOW_THUMB_DIR:-$HOME/.cache/hypr/screenshots/windows}"
WINDOW_THUMB_SIZE="${WINDOW_THUMB_SIZE:-180x110}"
WINDOW_ROFI_THEME="${WINDOW_ROFI_THEME:-$HOME/.config/rofi/themes/screenshot-window.rasi}"

window_rows() {
  local active_workspace

  active_workspace="$(hyprctl activeworkspace -j | jq -r '.id')"

  hyprctl clients -j | jq -r --argjson active_workspace "$active_workspace" '
    .[]
    | select(.mapped == true)
    | select(.hidden == false)
    | select(.workspace.id == $active_workspace)
    | {
        label: (
          (((.class // "unknown") | tostring) + " — " + (((.title // .initialTitle // "untitled") | tostring)))
          | gsub("[\t\n\r]"; " ")
        ),
        address: ((.address // "unknown") | tostring),
        toplevel: ((.stableId // "") | tostring),
        geometry: ((.at[0] | tostring) + "," + (.at[1] | tostring) + " " + (.size[0] | tostring) + "x" + (.size[1] | tostring))
      }
    | @base64
  '
}

window_menu() {
  if [[ -f "$WINDOW_ROFI_THEME" ]]; then
    rofi -dmenu -i -p "Window" -theme "$WINDOW_ROFI_THEME" "$@"
  else
    rofi_dmenu "Window" "$@"
  fi
}

window_thumb() {
  local row="$1"
  local address toplevel geometry cache_key raw thumb

  mkdir -p "$WINDOW_THUMB_DIR"

  address="$(printf '%s' "$row" | base64 -d | jq -r '.address')"
  toplevel="$(printf '%s' "$row" | base64 -d | jq -r '.toplevel')"
  geometry="$(printf '%s' "$row" | base64 -d | jq -r '.geometry')"
  cache_key="$(printf '%s-%s-%s' "$address" "$toplevel" "$geometry" | sha256sum | awk '{print $1}')"
  raw="$WINDOW_THUMB_DIR/$cache_key.raw.png"
  thumb="$WINDOW_THUMB_DIR/$cache_key.png"

  if [[ -n "$toplevel" ]] && grim -T "$toplevel" "$raw" >/dev/null 2>&1; then
    if command -v magick >/dev/null 2>&1 &&
      magick "$raw" -auto-orient -thumbnail "$WINDOW_THUMB_SIZE" "$thumb" >/dev/null 2>&1; then
      rm -f "$raw"
      printf '%s\n' "$thumb"
      return 0
    fi

    rm -f "$raw"
  fi

  printf '%s\n' "preferences-system-windows"
}

capture_window() {
  local row="$1"
  local output="$2"
  local toplevel geometry

  toplevel="$(printf '%s' "$row" | base64 -d | jq -r '.toplevel')"
  geometry="$(printf '%s' "$row" | base64 -d | jq -r '.geometry')"

  if [[ -n "$toplevel" ]] && grim -T "$toplevel" "$output"; then
    return 0
  fi

  capture_geometry "$geometry" "$output"
}

build_menu_rows() {
  local rows="$1"
  local menu_file="$2"
  local row

  while IFS= read -r row; do
    printf '%s\t%s\0icon\x1f%s\n' \
      "$(printf '%s' "$row" | base64 -d | jq -r '.label')" \
      "$row" \
      "$(window_thumb "$row")"
  done <<< "$rows" > "$menu_file"
}

main() {
  ensure_dependencies grim jq wl-copy hyprctl rofi sha256sum
  ensure_save_dir

  local rows selected label output menu_file
  rows="$(window_rows)"

  if [[ -z "$rows" ]]; then
    notify_error "Screenshot gagal" "Tidak ada window aktif."
    exit 1
  fi

  menu_file="$(mktemp)"
  trap 'rm -f "$menu_file"' EXIT
  build_menu_rows "$rows" "$menu_file"

  if ! selected="$(
    window_menu -show-icons -display-columns 1 < "$menu_file" |
      awk -F '\t' '{print $2}'
  )"; then
    notify_error "Screenshot dibatalkan" "Tidak ada window yang dipilih."
    exit 1
  fi

  if [[ -z "$selected" ]]; then
    notify_error "Screenshot dibatalkan" "Tidak ada window yang dipilih."
    exit 1
  fi

  label="$(printf '%s' "$selected" | base64 -d | jq -r '.label')"
  output="$(timestamp_path window)"

  if ! capture_window "$selected" "$output"; then
    notify_error "Screenshot gagal" "Capture window gagal: $label"
    exit 1
  fi

  finish_capture "$output" "Window screenshot"
}

main "$@"
