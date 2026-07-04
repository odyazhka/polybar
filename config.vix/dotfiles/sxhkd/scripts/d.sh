#!/bin/sh

# Отдельный файл состояния — не пересекается с zen mode (x.sh)
STATE_FILE="/tmp/bspwm_hide_all_$(bspc query -D -d)"

if [ -s "$STATE_FILE" ]; then
    # Файл есть — восстанавливаем скрытые окна
    while read -r wid; do
        if bspc query -N -n "$wid" > /dev/null 2>&1; then
            bspc node "$wid" -g hidden=off
        fi
    done < "$STATE_FILE"

    rm -f "$STATE_FILE"
else
    # Только видимые окна — уже скрытые не трогаем
    ALL_WIDS=$(bspc query -N -d -n .window.!hidden)

    [ -z "$ALL_WIDS" ] && exit 0

    > "$STATE_FILE"

    for wid in $ALL_WIDS; do
        bspc node "$wid" -g hidden=on
        echo "$wid" >> "$STATE_FILE"
    done
fi
