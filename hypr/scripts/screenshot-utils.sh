#!/usr/bin/env bash

# Shared config for the Hyprland screenshot workflow.
SAVE_DIR="${SAVE_DIR:-$HOME/Pictures/Screenshots}"
DATE_FORMAT="${DATE_FORMAT:-%Y-%m-%d_%H-%M-%S}"
ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/config.rasi}"
ENABLE_FREEZE="${ENABLE_FREEZE:-false}"
THUMB_DIR="${THUMB_DIR:-$HOME/.cache/hypr/screenshots/thumbs}"
NOTIFY_THUMB_SIZE="${NOTIFY_THUMB_SIZE:-360x240}"
NOTIFY_TIMEOUT="${NOTIFY_TIMEOUT:-5000}"
OPEN_COMMAND="${OPEN_COMMAND:-xdg-open}"

SCREENSHOT_ICON="${SCREENSHOT_ICON:-camera-photo}"

ensure_dependencies() {
  local missing=()

  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done

  if ((${#missing[@]} > 0)); then
    notify_error "Screenshot gagal" "Dependency belum ada: ${missing[*]}"
    return 1
  fi
}

ensure_save_dir() {
  mkdir -p "$SAVE_DIR"
}

ensure_thumb_dir() {
  mkdir -p "$THUMB_DIR"
}

timestamp_path() {
  local kind="${1:-screenshot}"
  local stamp

  stamp="$(date +"$DATE_FORMAT")"
  printf '%s/%s-%s.png\n' "$SAVE_DIR" "$kind" "$stamp"
}

notify_ok() {
  local title="$1"
  local body="${2:-}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -i "$SCREENSHOT_ICON" "$title" "$body"
  fi
}

notify_error() {
  local title="$1"
  local body="${2:-}"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical -i dialog-error "$title" "$body"
  fi
}

make_thumbnail() {
  local file="$1"
  local thumb="$THUMB_DIR/$(basename "${file%.png}").thumb.png"

  ensure_thumb_dir

  if command -v magick >/dev/null 2>&1 &&
    magick "$file" -auto-orient -thumbnail "$NOTIFY_THUMB_SIZE" "$thumb" >/dev/null 2>&1; then
    printf '%s\n' "$thumb"
    return 0
  fi

  printf '%s\n' "$file"
}

notify_screenshot() {
  local file="$1"
  local label="${2:-Screenshot}"
  local thumb action

  thumb="$(make_thumbnail "$file")"

  if ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi

  (
    action="$(
      notify-send \
        -a "Hyprland Screenshot" \
        -i "$thumb" \
        -h "string:image-path:$thumb" \
        -t "$NOTIFY_TIMEOUT" \
        -A open="Open" \
        -A folder="Folder" \
        "$label tersimpan" \
        "$file sudah tersimpan dan tercopy ke clipboard." || true
    )"

    case "$action" in
      open)
        command -v "$OPEN_COMMAND" >/dev/null 2>&1 && "$OPEN_COMMAND" "$file" >/dev/null 2>&1
        ;;
      folder)
        command -v "$OPEN_COMMAND" >/dev/null 2>&1 && "$OPEN_COMMAND" "$(dirname "$file")" >/dev/null 2>&1
        ;;
    esac
  ) &
}

copy_image() {
  local file="$1"

  wl-copy --type image/png < "$file"

  if command -v cliphist >/dev/null 2>&1; then
    cliphist store < "$file" || true
  fi
}

capture_full() {
  local output="$1"

  grim "$output"
}

capture_geometry() {
  local geometry="$1"
  local output="$2"

  grim -g "$geometry" "$output"
}

rofi_dmenu() {
  local prompt="$1"
  shift

  if [[ -f "$ROFI_THEME" ]]; then
    rofi -dmenu -i -p "$prompt" -theme "$ROFI_THEME" "$@"
  else
    rofi -dmenu -i -p "$prompt" "$@"
  fi
}

start_freeze() {
  FREEZE_PID=""

  if [[ "$ENABLE_FREEZE" != "true" ]]; then
    return 0
  fi

  if ! command -v hyprpicker >/dev/null 2>&1; then
    return 0
  fi

  # hyprpicker can render a frozen frame while slurp selects an area.
  hyprpicker -r -z >/dev/null 2>&1 &
  FREEZE_PID="$!"
  sleep 0.08
}

stop_freeze() {
  if [[ -n "${FREEZE_PID:-}" ]] && kill -0 "$FREEZE_PID" >/dev/null 2>&1; then
    kill "$FREEZE_PID" >/dev/null 2>&1 || true
  fi
}

finish_capture() {
  local file="$1"
  local label="${2:-Screenshot}"

  copy_image "$file"
  notify_screenshot "$file" "$label"
}
