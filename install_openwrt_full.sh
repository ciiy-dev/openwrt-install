#!/bin/sh

# Этот скрипт автоматизирует установку необходимых пакетов и скриптов
# для OpenWrt, включая отключение IPv6, internet-detector, podkop и YouTube Unblock.

# Устанавливаем режим выхода при первой же ошибке
set -e

echo "Начинаем установку пакетов и скриптов..."

echo "1/14: Отключение IPv6..."
# Скачиваем и выполняем скрипт для полного отключения IPv6
sh <(wget -O - https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/disable-ipv6-full.sh)
echo "IPv6 отключен."

echo "2/14: Обновление списка пакетов..."
# Обновляем список доступных пакетов
opkg update
echo "Список пакетов обновлен."

echo "3/14: Загрузка и установка internet-detector..."
# Загружаем пакет internet-detector
wget --no-check-certificate -O /tmp/internet-detector_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/internet-detector_1.6.1-r1_all.ipk
# Устанавливаем internet-detector
opkg install /tmp/internet-detector_1.6.1-r1_all.ipk
# Удаляем временный файл пакета
rm /tmp/internet-detector_1.6.1-r1_all.ipk
echo "internet-detector установлен."

echo "4/14: Запуск и включение internet-detector..."
# Запускаем службу internet-detector
service internet-detector start
# Включаем автоматический запуск internet-detector при загрузке
service internet-detector enable
echo "internet-detector запущен и включен."

echo "5/14: Загрузка и установка luci-app-internet-detector..."
# Загружаем пакет веб-интерфейса для internet-detector
wget --no-check-certificate -O /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-app-internet-detector_1.6.1-r1_all.ipk
# Устанавливаем luci-app-internet-detector
opkg install /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk
# Удаляем временный файл пакета
rm /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk
echo "luci-app-internet-detector установлен."

echo "6/14: Перезапуск rpcd..."
# Перезапускаем rpcd для обновления веб-интерфейса LuCI
service rpcd restart
echo "rpcd перезапущен."

echo "7/14: Загрузка и установка языкового пакета для internet-detector (русский)..."
# Загружаем русский языковой пакет для веб-интерфейса internet-detector
wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk
# Устанавливаем языковой пакет
opkg install /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk
# Удаляем временный файл пакета
rm /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk
echo "Языковой пакет установлен."

echo "8/14: Загрузка и выполнение скрипта podkop..."
# Скачиваем и выполняем скрипт установки podkop
sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh)
echo "Скрипт podkop выполнен."

echo "--- Настройка YouTube Unblock ---"
echo "9/14: Загрузка и установка YouTube Unblock (основной пакет)..."
# Загружаем основной пакет YouTube Unblock для архитектуры aarch64_cortex-a53
wget --no-check-certificate -O /tmp/youtubeUnblock-aarch64_cortex-a53.ipk https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/youtubeUnblock-1.0.0-10-f37c3dd-aarch64_cortex-a53-openwrt-23.05.ipk
# Устанавливаем основной пакет
opkg install /tmp/youtubeUnblock-aarch64_cortex-a53.ipk
# Удаляем временный файл
rm /tmp/youtubeUnblock-aarch64_cortex-a53.ipk
echo "Основной пакет YouTube Unblock установлен."

echo "10/14: Загрузка и установка YouTube Unblock (LuCI-интерфейс)..."
# Загружаем пакет LuCI-интерфейса для YouTube Unblock
wget --no-check-certificate -O /tmp/luci-app-youtubeUnblock.ipk https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk
# Устанавливаем пакет LuCI-интерфейса
opkg install /tmp/luci-app-youtubeUnblock.ipk
# Удаляем временный файл
rm /tmp/luci-app-youtubeUnblock.ipk
echo "LuCI-интерфейс YouTube Unblock установлен."

echo "11/14: Установка зависимостей для YouTube Unblock..."
# Устанавливаем необходимые зависимости для YouTube Unblock
opkg update # Обновляем на всякий случай
opkg install kmod-nfnetlink-queue kmod-nft-queue kmod-nf-conntrack curl
echo "Зависимости YouTube Unblock установлены."

echo "12/14: Добавление правил Firewall для YouTube Unblock..."
# Добавляем правила в firewall для работы приложения
nft add chain inet fw4 youtubeUnblock '{ type filter hook postrouting priority mangle - 1; policy accept; }'
nft add rule inet fw4 youtubeUnblock 'tcp dport 443 ct original packets < 20 counter queue num 537 bypass'
nft add rule inet fw4 youtubeUnblock 'meta l4proto udp ct original packets < 9 counter queue num 537 bypass'
nft insert rule inet fw4 output 'mark and 0x8000 == 0x8000 counter accept'
echo "Правила Firewall добавлены."

echo "13/14: Изменение файла ruleset.uc для YouTube Unblock..."
# Изменяем строку в файле ruleset.uc для корректной работы
# Ищем строку 'meta l4proto { tcp, udp } flow offload @ft;'
# И заменяем ее на 'meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;'
sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc
echo "Файл ruleset.uc изменен."

echo "14/14: Перезапуск Firewall..."
# Перезапускаем firewall для применения новых правил
fw4 restart
echo "Firewall перезапущен."

echo "--- Тестирование YouTube Unblock (необязательно) ---"
echo "Для проверки работы YouTube Unblock выполните следующие команды в SSH:"
echo "curl -o/dev/null -k --connect-to ::google.com -k -L -H Host: mirror.gcr.io https://test.googlevideo.com/v2/cimg/android/blobs/sha256:6fd8bdac3da660bde7bd0b6f2b6a46e1b686afb74b9a4614def32532b73f5eaa"
echo "curl -o/dev/null -k --connect-to ::google.com -k -L -H Host: mirror.gcr.io https://mirror.gcr.io/v2/cimg/android/blobs/sha256:6fd8bdac3da660bde7bd0b6f2b6a46e1b686afb74b9a4614def32532b73f5eaa"
echo "--- Важные ручные шаги после выполнения скрипта ---"
echo "1. Зайдите в веб-интерфейс роутера (LuCI)."
echo "2. Перейдите в раздел 'Службы' -> 'youtubeUnblock' -> 'Конфигурация'."
echo "3. Внизу найдите 'Default section', нажмите 'Клонировать', дайте название 'Google section'."
echo "4. Нажмите 'Изменить' на секции 'Google section' и настройте параметры (как на ваших скриншотах, убедитесь, что домены Google)."
echo "5. Сохраните изменения."
echo "6. Нажмите 'Изменить' на секции 'Default section' и настройте параметры (как на ваших скриншотах, добавьте нужные вам домены)."
echo "7. Сохраните изменения."
"8. Внизу страницы нажмите кнопку 'Применить'."
echo "9. Если какие-то сайты не открываются, проверьте 'Статус службы' в youtubeUnblock и скопируйте блокированные домены в секцию Default."

echo "Установка завершена. Рекомендуется перезагрузить роутер."
echo "Вы можете сделать это командой 'reboot'."
