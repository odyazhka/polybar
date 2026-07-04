#!/usr/bin/env bash

BATTERY="${BATTERY:-BAT0}"
MONITOR="${MONITOR:-default}"
SCRIPT="$(realpath "$0")"

FLAG="/tmp/polybar_battery_collapsed"
FIFO="/tmp/polybar_battery_fifo_${MONITOR}"

get_icon() {
    local pct="$1"
    local status
    status="$(cat "/sys/class/power_supply/${BATTERY}/status" 2>/dev/null || echo "Unknown")"
    if [[ "$status" == "Charging" ]]; then
        if   (( pct <= 10 )); then echo "󰁺󱐋"
        elif (( pct <= 30 )); then echo "󰁽󱐋"
        elif (( pct <= 55 )); then echo "󰁿󱐋"
        elif (( pct <= 80 )); then echo "󰂂󱐋"
        else                       echo "󰁹󱐋"
        fi
        return
    fi
    if   (( pct <= 10 )); then echo "󰁺"
    elif (( pct <= 30 )); then echo "󰁽"
    elif (( pct <= 55 )); then echo "󰁿"
    elif (( pct <= 80 )); then echo "󰂂"
    else                       echo "󰁹"
    fi
}

render() {
    local pct icon label=""
    pct="$(cat "/sys/class/power_supply/${BATTERY}/capacity" 2>/dev/null || echo "?")"
    icon="$(get_icon "${pct:-0}")"

    if [[ ! -f "$FLAG" ]] && [[ "$pct" != "?" ]]; then
        label=" ${pct}%"
    fi

    echo "%{A1:MONITOR=${MONITOR} ${SCRIPT} toggle:}${icon}${label}%{A}"
}

action_toggle() {
    if [ -f "$FLAG" ]; then
        rm "$FLAG"
    else
        touch "$FLAG"
    fi
    for f in /tmp/polybar_battery_fifo_*; do
        [ -p "$f" ] && echo "toggle" > "$f"
    done
}

run_loop() {
    rm -f "$FIFO"
    mkfifo "$FIFO"

    exec 3<>"$FIFO"

    ( while true; do sleep 30; echo "tick" >&3; done ) &
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
    render) render ;;
    *)      echo "Usage: $0 [loop|toggle|render]" >&2; exit 1 ;;
esac
