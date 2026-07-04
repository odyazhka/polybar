#!/usr/bin/env bash
# stol.sh — polybar module for BSPWM workspace switching

set -euo pipefail

MONITOR="${MONITOR:-default}"
SCRIPT="$(realpath "$0")"

FLAG="/tmp/polybar_stol_expanded_${MONITOR}"
FIFO="/tmp/polybar_stol_fifo_${MONITOR}"

get_desktops_for_monitor() {
    bspc query -D -m "$1" --names 2>/dev/null
}

get_focused_desktop() {
    bspc query -D -m "$1" -d focused --names 2>/dev/null | head -1
}

get_mode() {
    [[ -f "$FLAG" ]] && echo "expanded" || echo "collapsed"
}

set_mode() {
    if [[ "$1" == "expanded" ]]; then
        touch "$FLAG"
    else
        rm -f "$FLAG"
    fi
}

render() {
    local mode focused output=""
    mode="$(get_mode)"
    focused="$(get_focused_desktop "$MONITOR")"
    mapfile -t desktops < <(get_desktops_for_monitor "$MONITOR")

    if [[ "$mode" == "collapsed" ]]; then
        echo "%{A1:MONITOR=${MONITOR} ${SCRIPT} toggle:}%{O4}${focused}%{O4}%{A}"
        return
    fi

    local first=1
    for d in "${desktops[@]}"; do
        local sep=""
        [[ "$first" == "0" ]] && sep=" "
        if [[ "$d" == "$focused" ]]; then
            output+="${sep}[${d}]"
        else
            output+="%{A1:MONITOR=${MONITOR} ${SCRIPT} switch ${d}:}${sep}${d} %{A}"
        fi
        first=0
    done

    echo "%{O4}${output% }%{O4}"
}

action_toggle() {
    local cur
    cur="$(get_mode)"
    [[ "$cur" == "collapsed" ]] && set_mode "expanded" || set_mode "collapsed"
    [ -p "$FIFO" ] && echo "toggle" > "$FIFO"
}

action_switch() {
    bspc desktop -f "$1"
    set_mode "collapsed"
    [ -p "$FIFO" ] && echo "switch" > "$FIFO"
}

run_loop() {
    rm -f "$FIFO"
    mkfifo "$FIFO"

    exec 3<>"$FIFO"

    bspc subscribe desktop_focus desktop_add desktop_remove \
        desktop_rename node_transfer >&3 &
    bspc_pid=$!

    cleanup() { kill "$bspc_pid" 2>/dev/null; exec 3>&-; rm -f "$FIFO"; }
    trap cleanup EXIT

    render
    while read -r _event <&3; do
        render
    done
}

case "${1:-loop}" in
    loop)   run_loop ;;
    toggle) action_toggle ;;
    switch)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 switch <desktop>" >&2; exit 1; }
        action_switch "$2"
        ;;
    render) render ;;
    *)      echo "Usage: $0 [loop|toggle|switch <desktop>|render]" >&2; exit 1 ;;
esac
