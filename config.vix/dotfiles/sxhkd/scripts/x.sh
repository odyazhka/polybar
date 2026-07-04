#!/bin/sh

# Файл состояния для конкретного рабочего стола
STATE_FILE="/tmp/bspwm_zen_mode_$(bspc query -D -d)"

# Функция для восстановления окон
restore_windows() {
    if [ -f "$STATE_FILE" ]; then
        while read -r wid; do
            if bspc query -N -n "$wid" > /dev/null 2>&1; then
                bspc node "$wid" -g hidden=off
            fi
        done < "$STATE_FILE"
        rm -f "$STATE_FILE"
    fi
}

if [ -f "$STATE_FILE" ]; then
    # Если файл есть — принудительно восстанавливаем (ручной выход из Zen)
    restore_windows
    # Убиваем фоновый процесс слежки, если он ещё жив
    pkill -f "bspc subscribe node_remove"
else
    # ВХОД В ZEN MODE
    CUR_WID=$(bspc query -N -n)
    [ -z "$CUR_WID" ] && exit 0

    ALL_WIDS=$(bspc query -N -d -n .window)
    > "$STATE_FILE"

    for wid in $ALL_WIDS; do
        if [ "$wid" != "$CUR_WID" ]; then
            bspc node "$wid" -g hidden=on
            echo "$wid" >> "$STATE_FILE"
        fi
    done

    # Фоновый цикл: ждём закрытия zen-окна
    (
        # Если bspwm перезапустится — bspc subscribe получит EOF и подоболочка
        # выйдет. trap на EXIT чистит STATE_FILE, чтобы следующий super+x
        # не думал что zen mode всё ещё активен.
        trap 'rm -f "$STATE_FILE"' EXIT

        bspc subscribe node_remove | while read -r _ _ _ wid; do
            if [ "$wid" = "$CUR_WID" ]; then
                restore_windows
                break
            fi
        done
    ) &
fi
