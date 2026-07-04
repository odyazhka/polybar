#!/bin/sh

menu_rows=$(cat <<EOF
󰐥	Выключение <span size="small" style="italic" weight="light">(shutdown)</span>
󰑓	Перезагрузка <span size="small" style="italic" weight="light">(reboot)</span>
󰤄	Спящий режим <span size="small" style="italic" weight="light">(zzz)</span>
H	Гибернация <span size="small" style="italic" weight="light">(ZZZ)</span>
	Заблокировать <span size="small" style="italic" weight="light">(xlock)</span>
󰍃	Выйти <span size="small" style="italic" weight="light">(pkill -u $USER)</span>
󰟵	Изменить пароль <span size="small" style="italic" weight="light">(passwd)</span>
	Диспетчер задач <span size="small" style="italic" weight="light">(btop)</span>
EOF
)

# Вызов Rofi с флагом -markup-rows для обработки тегов
chosen=$(echo "$menu_rows" | rofi -dmenu -markup-rows -i -p "Завершение работы ")

case "$chosen" in
    *"Выключение"*) sudo shutdown -h now ;;
    *"Перезагрузка"*) sudo reboot ;;
    *"Спящий режим"*) sudo zzz ;;
    *"Гибернация"*) sudo ZZZ ;;
    *"Заблокировать"*) ~/.config/polybar/scripts/xlock.sh ;;
    *"Выйти"*) pkill -u $USER ;;
    *"Изменить пароль"*) xterm -e passwd ;;
    *"Диспетчер задач"*) xterm -e btop ;;
esac
