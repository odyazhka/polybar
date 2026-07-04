#!/usr/bin/env bash

MONITOR="${MONITOR:-default}"
FLAG="/tmp/polybar_date_toggle"
FIFO="/tmp/polybar_date_fifo_${MONITOR}"

render() {
    if [ -f "$FLAG" ]; then
        date +"%d.%m.%Y"
    else
        LANG=ru_RU.UTF-8 date +"%a, %-d %B"
    fi
}

action_toggle() {
    if [ -f "$FLAG" ]; then
        rm "$FLAG"
    else
        touch "$FLAG"
    fi
    # Уведомить все мониторы
    for f in /tmp/polybar_date_fifo_*; do
        [ -p "$f" ] && echo "toggle" > "$f"
    done
}

run_loop() {
    rm -f "$FIFO"
    mkfifo "$FIFO"

    exec 3<>"$FIFO"

    ( while true; do sleep 60; echo "tick" >&3; done ) &
    ticker_pid=$!

    cleanup() { kill "$ticker_pid" 2>/dev/null; exec 3>&-; rm -f "$FIFO"; }
    trap cleanup EXIT

    render
    while read -r _event <&3; do
        render
    done
}

case "${1:-loop}" in
    loop)   run_loop ;;
    toggle) action_toggle ;;
    *)      echo "Usage: $0 [loop|toggle]" >&2; exit 1 ;;
esac
