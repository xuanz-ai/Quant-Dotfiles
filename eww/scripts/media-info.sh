#!/bin/bash
# EWW media info provider — cache-based
#   media-info.sh          → writes JSON state to cache, outputs full JSON
#   media-info.sh <field>  → outputs just that field from cache
#
# Called by multiple defpoll instances; only the first each second
# does the real playerctl query, the rest read from the JSON cache.

CACHE_DIR="/tmp/eww-media"
CACHE_FILE="$CACHE_DIR/state.json"

mkdir -p "$CACHE_DIR"

# ── Helpers ──────────────────────────────────────────────

fmt_time() {
  local secs="${1%.*}"
  (( secs > 0 )) || { echo "0:00"; return; }
  printf "%d:%02d" $(( secs / 60 )) $(( secs % 60 ))
}

youtube_id() {
  local url="$1"
  local watch_re='(youtube\.com|music\.youtube\.com).*[?&]v=([A-Za-z0-9_-]+)'
  local short_re='youtu\.be/([A-Za-z0-9_-]+)'
  local path_re='youtube\.com/(shorts|embed)/([A-Za-z0-9_-]+)'

  if [[ "$url" =~ $watch_re ]]; then
    echo "${BASH_REMATCH[2]}"
  elif [[ "$url" =~ $short_re ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$url" =~ $path_re ]]; then
    echo "${BASH_REMATCH[2]}"
  fi
}

select_player() {
  local first="" paused="" player status

  while IFS= read -r player; do
    [ -n "$player" ] || continue
    [ -n "$first" ] || first="$player"

    status=$(playerctl -p "$player" status 2>/dev/null || echo "")
    case "$status" in
      Playing)
        echo "$player"
        return 0
        ;;
      Paused)
        [ -n "$paused" ] || paused="$player"
        ;;
    esac
  done < <(playerctl -l 2>/dev/null)

  if [ -n "$paused" ]; then
    echo "$paused"
  else
    echo "$first"
  fi
}

# ── Cache refresh ────────────────────────────────────────

maybe_refresh() {
  local age=999
  [ -f "$CACHE_FILE" ] && age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
  [ "$age" -le 1 ] && return 0

  # ── Volume ──────────────────────────────────────────
  local vol muted vol_icon
  vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2 * 100)}')
  [ -n "$vol" ] || vol=0
  if wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED; then
    muted=true
  else
    muted=false
  fi

  if [ "$muted" = "true" ] || [ "$vol" -eq 0 ]; then
    vol_icon="󰝟"
  elif [ "$vol" -lt 34 ]; then
    vol_icon="󰕿"
  elif [ "$vol" -lt 67 ]; then
    vol_icon="󰖀"
  else
    vol_icon="󰕾"
  fi

  # ── Media ───────────────────────────────────────────
  local player title artist art_url track_url status length position
  local len_sec pos_sec position_pct playing play_icon art_path
  local art_hash art_file art_src art_sig ytid tmp_art

  player=$(select_player)

  if [ -z "$player" ]; then
    jq -nc '{
      available: false, title: "No media playing", artist: "",
      art_path: "", status: "Stopped", playing: false,
      position_pct: 0, position_str: "0:00", duration_str: "0:00",
      play_icon: "", volume: $vol, muted: $muted, vol_icon: $vicon,
      vol_str: $vstr
    }' \
      --argjson vol "$vol" \
      --argjson muted "$muted" \
      --arg vicon "$vol_icon" \
      --arg vstr "${vol}%" > "$CACHE_FILE"
    return 0
  fi

  title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "Unknown Title")
  artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "Unknown Artist")
  art_url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || echo "")
  track_url=$(playerctl -p "$player" metadata xesam:url 2>/dev/null || echo "")
  status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
  length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null || echo "0")
  position=$(playerctl -p "$player" position 2>/dev/null || echo "0")

  len_us=${length%%.*}
  pos_sec=${position%%.*}
  len_sec=$(( len_us / 1000000 ))

  [ "$len_sec" -gt 0 ] && position_pct=$(( pos_sec * 100 / len_sec )) || position_pct=0

  if [ "$status" = "Playing" ]; then
    playing=true; play_icon=""
  else
    playing=false; play_icon=""
  fi

  # Album art
  art_path=""
  if [ -n "$art_url" ]; then
    if [[ "$art_url" == http* ]]; then
      art_hash=$(echo "$art_url" | md5sum | cut -d' ' -f1)
      art_file="$CACHE_DIR/$art_hash"
      if [ ! -f "$art_file" ]; then
        find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null
        curl -sS "$art_url" -o "$art_file" 2>/dev/null
      fi
      [ -s "$art_file" ] && art_path="$art_file"
    elif [[ "$art_url" == file://* ]]; then
      art_src="${art_url#file://}"
      if [ -f "$art_src" ]; then
        art_sig=$(stat -c '%Y:%s' "$art_src" 2>/dev/null || echo "")
        art_hash=$(printf '%s:%s' "$art_url" "$art_sig" | md5sum | cut -d' ' -f1)
        art_file="$CACHE_DIR/$art_hash"
        if [ ! -f "$art_file" ]; then
          find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null
          cp "$art_src" "$art_file" 2>/dev/null
        fi
        [ -s "$art_file" ] && art_path="$art_file"
      fi
    fi
  fi

  if [ -z "$art_path" ] && [ -n "$track_url" ]; then
    ytid=$(youtube_id "$track_url")
    if [ -n "$ytid" ]; then
      art_file="$CACHE_DIR/yt-$ytid.jpg"
      if [ ! -f "$art_file" ]; then
        find "$CACHE_DIR" -type f -mmin +60 -delete 2>/dev/null
        tmp_art="$art_file.tmp"
        if curl -fsSL "https://i.ytimg.com/vi/$ytid/hqdefault.jpg" -o "$tmp_art" 2>/dev/null; then
          mv "$tmp_art" "$art_file"
        else
          rm -f "$tmp_art"
        fi
      fi
      [ -s "$art_file" ] && art_path="$art_file"
    fi
  fi

  jq -nc '{
    available: true, title: $title, artist: $artist,
    art_path: $art, status: $status,
    playing: $playing, position_pct: $pct,
    position_str: $pos_str, duration_str: $dur_str,
    play_icon: $play_icon, volume: $vol, muted: $muted,
    vol_icon: $vicon, vol_str: $vstr
  }' \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg art "$art_path" \
    --arg status "$status" \
    --argjson playing "$playing" \
    --argjson pct "$position_pct" \
    --arg pos_str "$(fmt_time "$pos_sec")" \
    --arg dur_str "$(fmt_time "$len_sec")" \
    --arg play_icon "$play_icon" \
    --argjson vol "$vol" \
    --argjson muted "$muted" \
    --arg vicon "$vol_icon" \
    --arg vstr "${vol}%" \
    > "$CACHE_FILE"
}

# ── Main ─────────────────────────────────────────────────

maybe_refresh

if [ -n "$1" ]; then
  val=$(jq -r ".${1} // empty" "$CACHE_FILE" 2>/dev/null)
  if [ -z "$val" ]; then
    case "$1" in
      position_pct|volume) echo "0" ;;
      *) echo "" ;;
    esac
  else
    echo "$val"
  fi
else
  cat "$CACHE_FILE" 2>/dev/null
fi
