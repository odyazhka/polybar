#!/bin/sh

# Завершить уже запущенные процессы панели
pkill polybar

# Убить хвостовые скрипты от прошлого запуска
pkill -f "date.sh loop"
pkill -f "battery.sh loop"
pkill -f "stol.sh loop"

# Почистить старые FIFO и флаги состояния
rm -f /tmp/polybar_*

# Ожидание закрытия процессов
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main &
    sleep 0.5
done
