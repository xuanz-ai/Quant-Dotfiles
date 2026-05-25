#!/usr/bin/env bash

# Toggle floating for the active window, and if it becomes floating,
# resize it to a desired width/height (pixels).

DESIRED_W=850
DESIRED_H=500

active_info=$(hyprctl activewindow)
if [ -z "$active_info" ]; then
    exit 1
fi

floating_before=$(printf '%s\n' "$active_info" | awk '/floating:/ {print $2; exit}')
if [ -z "$floating_before" ]; then
    floating_before=0
fi

if [ "$floating_before" -eq 0 ]; then
    hyprctl dispatch togglefloating
    sleep 0.08
    active_info=$(hyprctl activewindow)
    size_line=$(printf '%s\n' "$active_info" | awk '/size:/ {print $0; exit}')
    if printf '%s\n' "$size_line" | grep -q 'size:'; then
        read curW curH < <(printf '%s\n' "$size_line" | sed -n 's/.*size: \([0-9]*\),\([0-9]*\).*/\1 \2/p')
        if [ -n "$curW" ] && [ -n "$curH" ]; then
            deltaW=$((DESIRED_W - curW))
            deltaH=$((DESIRED_H - curH))
            if [ "$deltaW" -ne 0 ] || [ "$deltaH" -ne 0 ]; then
                hyprctl dispatch resizeactive "$deltaW" "$deltaH"
            fi
        fi
    fi
else
    hyprctl dispatch togglefloating
fi

exit 0
