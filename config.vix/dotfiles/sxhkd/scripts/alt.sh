#!/bin/bash
# bspwm-drag-split.sh
# Зависимости: xdotool, xinput, bspc
#
# Устройство определяется автоматически:
#   1. Переменная ALT_DEVICE (частичное совпадение имени)   — наивысший приоритет
#   2. Первая внешняя мышь (не Synaptics, не тачпад, не XTEST, не Keyboard)
#   3. Тачпад как fallback (если внешней мыши нет)
#
# Пример ручного override:
#   ALT_DEVICE="G102" ~/.config/sxhkd/scripts/alt.sh

_find_pointer_device() {
    if [ -n "${ALT_DEVICE:-}" ]; then
        xinput list --name-only 2>/dev/null \
            | grep -i "$ALT_DEVICE" \
            | grep -iv "keyboard\|consumer" \
            | head -1
        return
    fi

    local xinput_out
    xinput_out=$(xinput list 2>/dev/null)

    # Приоритет 1: внешняя мышь (slave pointer, не тачпад, не Keyboard)
    local external
    external=$(echo "$xinput_out" \
        | grep "slave  pointer" \
        | grep -iv "xtest\|keyboard\|touchpad\|consumer\|synaptics\|syna[0-9]" \
        | grep -oP '↳ \K[^\t]+(?=\s+id=)' \
        | sed 's/[[:space:]]*$//' \
        | head -1)

    if [ -n "$external" ]; then
        echo "$external"
        return
    fi

    # Fallback: тачпад
    echo "$xinput_out" \
        | grep "slave  pointer" \
        | grep -iv "xtest\|keyboard\|consumer" \
        | grep -oP '↳ \K[^\t]+(?=\s+id=)' \
        | sed 's/[[:space:]]*$//' \
        | head -1
}

# --- Определяем устройство ---
DEVICE=$(_find_pointer_device)

if [ -z "$DEVICE" ]; then
    notify-send -u low "alt.sh" "Не найдено pointer-устройство" 2>/dev/null
    exit 1
fi

# --- 1. Запоминаем окно A ---
NODE_A=$(bspc query -N -n focused 2>/dev/null)
[ -z "$NODE_A" ] && exit 1

WIN_A=$(xdotool getactivewindow 2>/dev/null)
[ -z "$WIN_A" ] && exit 1

LAST_NODE_B=""
LAST_DIR=""

# --- Сохраняем и отключаем presel-подсветку ---
ORIG_PRESEL_COLOR=$(bspc config presel_feedback_color 2>/dev/null)
ORIG_PRESEL_FEEDBACK=$(bspc config presel_feedback 2>/dev/null)
bspc config presel_feedback_color "#00000000" 2>/dev/null
bspc config presel_feedback false 2>/dev/null

restore_presel() {
    bspc config presel_feedback_color "$ORIG_PRESEL_COLOR" 2>/dev/null
    bspc config presel_feedback "$ORIG_PRESEL_FEEDBACK" 2>/dev/null
}
trap restore_presel EXIT

# --- 2. Фоновый цикл предпросмотра пока зажата кнопка ---
preview_loop() {
    while true; do
        INFO=$(xdotool getmouselocation --shell 2>/dev/null)
        WIN_B=$(echo "$INFO" | grep "^WINDOW=" | cut -d= -f2)

        if [ -z "$WIN_B" ] || [ "$WIN_B" = "0" ] || [ "$WIN_B" = "$WIN_A" ]; then
            sleep 0.05
            continue
        fi

        NODE_B=$(bspc query -N -n "$WIN_B" 2>/dev/null)
        if [ -z "$NODE_B" ] || [ "$NODE_B" = "$NODE_A" ]; then
            sleep 0.05
            continue
        fi

        CX=$(echo "$INFO" | grep "^X=" | cut -d= -f2)
        CY=$(echo "$INFO" | grep "^Y=" | cut -d= -f2)

        GEOM=$(xdotool getwindowgeometry --shell "$WIN_B" 2>/dev/null)
        WIN_X=$(echo "$GEOM" | grep "^X="      | cut -d= -f2)
        WIN_Y=$(echo "$GEOM" | grep "^Y="      | cut -d= -f2)
        WIN_W=$(echo "$GEOM" | grep "^WIDTH="  | cut -d= -f2)
        WIN_H=$(echo "$GEOM" | grep "^HEIGHT=" | cut -d= -f2)

        CENTER_X=$(( WIN_X + WIN_W / 2 ))
        CENTER_Y=$(( WIN_Y + WIN_H / 2 ))

        # Форма окна определяет ось, курсор — сторону
        if [ "${WIN_W:-0}" -gt "${WIN_H:-0}" ]; then
            [ "${CX:-0}" -lt "$CENTER_X" ] && DIR="west" || DIR="east"
        else
            [ "${CY:-0}" -lt "$CENTER_Y" ] && DIR="north" || DIR="south"
        fi

        if [ "$NODE_B" != "$LAST_NODE_B" ] || [ "$DIR" != "$LAST_DIR" ]; then
            NODE_A=$(bspc query -N -n focused 2>/dev/null)
            [ -z "$NODE_A" ] && { sleep 0.05; continue; }

            bspc node "$NODE_B" --presel-dir "$DIR" 2>/dev/null
            bspc node "$NODE_A" --to-node "$NODE_B" --follow 2>/dev/null
            bspc node "$NODE_B" --presel-dir cancel 2>/dev/null

            LAST_NODE_B="$NODE_B"
            LAST_DIR="$DIR"
        fi

        sleep 0.05
    done
}

preview_loop &
PREVIEW_PID=$!

# Убиваем preview_loop при любом выходе (SIGTERM, ошибка xinput и т.д.)
cleanup() {
    kill "$PREVIEW_PID" 2>/dev/null
    wait "$PREVIEW_PID" 2>/dev/null
}
trap 'cleanup' EXIT

# --- 3. Ждём отпускания ЛКМ ---
xinput test "$DEVICE" 2>/dev/null | grep -m1 "button release 1"

exit 0
