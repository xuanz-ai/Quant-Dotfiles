#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/screenshot-utils.sh"

CLIPBOARD_MAX_ITEMS="${CLIPBOARD_MAX_ITEMS:-40}"
CLIPBOARD_THUMB_DIR="${CLIPBOARD_THUMB_DIR:-$HOME/.cache/hypr/clipboard/thumbs}"
CLIPBOARD_THUMB_SIZE="${CLIPBOARD_THUMB_SIZE:-160x110}"
CLIPBOARD_ROFI_THEME="${CLIPBOARD_ROFI_THEME:-$HOME/.config/rofi/themes/clipboard.rasi}"

clipboard_rofi() {
  local prompt="$1"
  shift

  if [[ -f "$CLIPBOARD_ROFI_THEME" ]]; then
    rofi -dmenu -i -p "$prompt" -theme "$CLIPBOARD_ROFI_THEME" "$@"
  else
    rofi_dmenu "$prompt" "$@"
  fi
}

clean_label() {
  local row="$1"

  printf '%s' "$row" |
    sed -E 's/^[0-9]+\t?//; s/[[:cntrl:]]+/ /g; s/[[:space:]]+/ /g; s/^ //; s/ $//' |
    cut -c 1-120
}

row_maybe_image() {
  local row="$1"

  [[ "$row" == *"image/"* || "$row" == *"binary data"* || "$row" == *"PNG image"* ]]
}

thumbnail_for_row() {
  local row="$1"
  local encoded="$2"
  local cache_key source_file thumb_file mime

  mkdir -p "$CLIPBOARD_THUMB_DIR"

  cache_key="$(printf '%s' "$encoded" | sha256sum | awk '{print $1}')"
  source_file="$CLIPBOARD_THUMB_DIR/$cache_key.source"
  thumb_file="$CLIPBOARD_THUMB_DIR/$cache_key.png"

  if [[ -f "$thumb_file" ]]; then
    printf '%s\n' "$thumb_file"
    return 0
  fi

  if ! row_maybe_image "$row"; then
    printf '%s\n' "edit-paste"
    return 0
  fi

  if ! printf '%s\n' "$row" | cliphist decode > "$source_file" 2>/dev/null; then
    rm -f "$source_file"
    printf '%s\n' "image-x-generic"
    return 0
  fi

  mime="$(file --mime-type -b "$source_file" 2>/dev/null || true)"
  if [[ "$mime" == image/* ]] && command -v magick >/dev/null 2>&1; then
    magick "$source_file" -auto-orient -thumbnail "$CLIPBOARD_THUMB_SIZE" "$thumb_file" >/dev/null 2>&1 || true
  fi

  rm -f "$source_file"

  if [[ -f "$thumb_file" ]]; then
    printf '%s\n' "$thumb_file"
  else
    printf '%s\n' "image-x-generic"
  fi
}

rofi_rows() {
  local row encoded label icon

  cliphist list | head -n "$CLIPBOARD_MAX_ITEMS" | while IFS= read -r row; do
    [[ -z "$row" ]] && continue

    encoded="$(printf '%s' "$row" | base64 -w 0)"
    label="$(clean_label "$row")"
    [[ -z "$label" ]] && label="Clipboard item"
    icon="$(thumbnail_for_row "$row" "$encoded")"

    printf '%s\t%s\0icon\x1f%s\n' "$label" "$encoded" "$icon"
  done
}

decode_to_clipboard() {
  local encoded="$1"

  printf '%s' "$encoded" | base64 -d | cliphist decode | wl-copy
}

open_image_preview() {
  local encoded="$1"
  local preview_file mime

  preview_file="$(mktemp --suffix=.clipboard-preview.png)"
  printf '%s' "$encoded" | base64 -d | cliphist decode > "$preview_file"

  mime="$(file --mime-type -b "$preview_file" 2>/dev/null || true)"
  if [[ "$mime" != image/* ]]; then
    rm -f "$preview_file"
    notify_error "Clipboard preview gagal" "Item yang dipilih bukan gambar."
    return 1
  fi

  if command -v "$OPEN_COMMAND" >/dev/null 2>&1; then
    "$OPEN_COMMAND" "$preview_file" >/dev/null 2>&1 &
  else
    notify_error "Clipboard preview gagal" "$OPEN_COMMAND tidak ditemukan."
    return 1
  fi
}

main() {
  ensure_dependencies cliphist wl-copy rofi base64 file sha256sum

  local selected status encoded

  set +e
  selected="$(
    rofi_rows |
      clipboard_rofi "Clipboard" \
        -show-icons \
        -display-columns 1 \
        -kb-custom-1 "Alt+Return" \
        -mesg "Enter: copy  |  Alt+Enter: open image preview"
  )"
  status=$?
  set -e

  if [[ "$status" -ne 0 && "$status" -ne 10 ]]; then
    notify_error "Clipboard dibatalkan" "Tidak ada item yang dipilih."
    exit 1
  fi

  encoded="$(awk -F '\t' '{print $2}' <<< "$selected")"
  if [[ -z "$encoded" ]]; then
    notify_error "Clipboard dibatalkan" "Tidak ada item yang dipilih."
    exit 1
  fi

  if [[ "$status" -eq 10 ]]; then
    open_image_preview "$encoded"
    exit 0
  fi

  decode_to_clipboard "$encoded"
  notify_ok "Clipboard aktif" "Item dipilih ulang ke clipboard."
}

main "$@"
