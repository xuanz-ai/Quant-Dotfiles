#!/bin/bash

DIR="$HOME/Pictures/wallpapers"

THEME="$HOME/.config/rofi/themes/wallpaper.rasi"

selected=$(find "$DIR" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.webp" \) | while read -r img; do

    printf "%s\x00icon\x1f%s\n" "$(basename "$img")" "$img"

done | rofi -dmenu \
            -show-icons \
            -theme "$THEME")

[ -z "$selected" ] && exit

wallpaper=$(find "$DIR" -type f -name "$selected" -print -quit)

[ -z "$wallpaper" ] && exit

CONFIG="$HOME/.config/hypr/hyprpaper.conf"

MONITOR=$(hyprctl monitors | grep "Monitor" | awk '{print $2}' | head -1)
[ -z "$MONITOR" ] && MONITOR=$(awk -F'=' '/^[[:space:]]*monitor[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$CONFIG")
[ -z "$MONITOR" ] && MONITOR="eDP-1"

cat > "$CONFIG" <<EOF
wallpaper {
    monitor = $MONITOR
    path = $wallpaper
    fit_mode = cover
}

splash = false
ipc = true
EOF

hyprctl hyprpaper wallpaper "$MONITOR,$wallpaper,cover" && exit

pkill hyprpaper
hyprctl dispatch exec hyprpaper
