#!/bin/sh

# Этот скрипт автоматизирует установку необходимых пакетов и скриптов
# для OpenWrt, включая отключение IPv6, internet-detector и podkop.

# Устанавливаем режим выхода при первой же ошибке
set -e

# ANSI escape codes for colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Начинаем установку пакетов и скриптов...${NC}"

echo -e "${YELLOW}1/8: Отключение IPv6...${NC}"
# Скачиваем и выполняем улучшенный скрипт для полного отключения IPv6
# Используем локальный скрипт с более эффективными командами
if [ -f "./disable-ipv6-full.sh" ]; then
    sh ./disable-ipv6-full.sh
else
    # Если локальный скрипт не найден, загружаем с репозитория
    wget -O /tmp/disable-ipv6-full.sh https://raw.githubusercontent.com/Davoyan/router-xray-fakeip-installation/main/disable-ipv6-full.sh >/dev/null 2>&1
    chmod +x /tmp/disable-ipv6-full.sh
    sh /tmp/disable-ipv6-full.sh
    rm -f /tmp/disable-ipv6-full.sh
fi
echo -e "${GREEN}IPv6 отключен с использованием улучшенного скрипта.${NC}"

echo -e "${YELLOW}2/8: Обновление списка пакетов...${NC}"
# Обновляем список доступных пакетов, подавляя обычный вывод
opkg update >/dev/null 2>&1
echo -e "${GREEN}Список пакетов обновлен.${NC}"

echo -e "${YELLOW}3/8: Загрузка и установка internet-detector...${NC}"
# Загружаем пакет internet-detector, подавляя обычный вывод wget
wget --no-check-certificate -O /tmp/internet-detector_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/internet-detector_1.6.1-r1_all.ipk >/dev/null 2>&1
# Устанавливаем internet-detector, подавляя обычный вывод opkg
opkg install /tmp/internet-detector_1.6.1-r1_all.ipk >/dev/null 2>&1
# Удаляем временный файл пакета
rm /tmp/internet-detector_1.6.1-r1_all.ipk
echo -e "${GREEN}internet-detector установлен.${NC}"

echo -e "${YELLOW}4/8: Запуск и включение internet-detector...${NC}"
# Запускаем службу internet-detector
service internet-detector start >/dev/null 2>&1
# Включаем автоматический запуск internet-detector при загрузке
service internet-detector enable >/dev/null 2>&1
echo -e "${GREEN}internet-detector запущен и включен.${NC}"

echo -e "${YELLOW}5/8: Загрузка и установка luci-app-internet-detector...${NC}"
# Загружаем пакет веб-интерфейса для internet-detector
wget --no-check-certificate -O /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-app-internet-detector_1.6.1-r1_all.ipk >/dev/null 2>&1
# Устанавливаем luci-app-internet-detector
opkg install /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk >/dev/null 2>&1
# Удаляем временный файл пакета
rm /tmp/luci-app-internet-detector_1.6.1-r1_all.ipk
echo -e "${GREEN}luci-app-internet-detector установлен.${NC}"

echo -e "${YELLOW}6/8: Перезапуск rpcd...${NC}"
# Перезапускаем rpcd для обновления веб-интерфейса LuCI
service rpcd restart >/dev/null 2>&1
echo -e "${GREEN}rpcd перезапущен.${NC}"

echo -e "${YELLOW}7/8: Загрузка и установка языкового пакета для internet-detector (русский)...${NC}"
# Загружаем русский языковой пакет для веб-интерфейса internet-detector
wget --no-check-certificate -O /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk >/dev/null 2>&1
# Устанавливаем языковой пакет
opkg install /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk >/dev/null 2>&1
# Удаляем временный файл пакета
rm /tmp/luci-i18n-internet-detector-ru_1.6.1-r1_all.ipk
echo -e "${GREEN}Языковой пакет установлен.${NC}"

echo -e "${YELLOW}8/8: Загрузка и выполнение скрипта podkop (автоматическая установка русского языка)...${NC}"
# Скачиваем и выполняем скрипт установки podkop, автоматически отвечая 'y' на вопрос о русском языке
echo y | sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh 2>/dev/null)
echo -e "${GREEN}Скрипт podkop выполнен.${NC}"

echo -e "${YELLOW}--- Настройка YouTube Unblock ---${NC}"
echo -e "${YELLOW}9/14: Установка зависимостей для YouTube Unblock...${NC}"
# Устанавливаем необходимые зависимости для YouTube Unblock
opkg update >/dev/null 2>&1 # Обновляем на всякий случай
opkg install kmod-nfnetlink-queue kmod-nft-queue kmod-nf-conntrack curl >/dev/null 2>&1
echo -e "${GREEN}Зависимости YouTube Unblock установлены.${NC}"

echo -e "${YELLOW}10/14: Загрузка и установка YouTube Unblock (основной пакет)...${NC}"
# Загружаем основной пакет YouTube Unblock для архитектуры aarch64_cortex-a53
wget --no-check-certificate -O /tmp/youtubeUnblock-aarch64_cortex-a53.ipk https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/youtubeUnblock-1.0.0-10-f37c3dd-aarch64_cortex-a53-openwrt-23.05.ipk >/dev/null 2>&1
# Устанавливаем основной пакет
opkg install /tmp/youtubeUnblock-aarch64_cortex-a53.ipk >/dev/null 2>&1
# Удаляем временный файл
rm /tmp/youtubeUnblock-aarch64_cortex-a53.ipk
echo -e "${GREEN}Основной пакет YouTube Unblock установлен.${NC}"

echo -e "${YELLOW}11/14: Загрузка и установка YouTube Unblock (LuCI-интерфейс)...${NC}"
# Загружаем пакет LuCI-интерфейса для YouTube Unblock
wget --no-check-certificate -O /tmp/luci-app-youtubeUnblock.ipk https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk >/dev/null 2>&1
# Устанавливаем пакет LuCI-интерфейса
opkg install /tmp/luci-app-youtubeUnblock.ipk >/dev/null 2>&1
# Удаляем временный файл
rm /tmp/luci-app-youtubeUnblock.ipk
echo -e "${GREEN}LuCI-интерфейс YouTube Unblock установлен.${NC}"

echo -e "${YELLOW}12/14: Добавление правил Firewall для YouTube Unblock...${NC}"
# Добавляем правила в firewall для работы приложения
# Ошибки "No such file or directory" при добавлении правил nftables могут быть связаны с тем,
# что youtubeUnblock пытается добавить их до того, как необходимые модули ядра
# kmod-nfnetlink-queue и kmod-nft-queue полностью загружены или настроены.
# Мы перенесли установку этих зависимостей выше, чтобы минимизировать эту проблему.
nft add chain inet fw4 youtubeUnblock '{ type filter hook postrouting priority mangle - 1; policy accept; }'
nft add rule inet fw4 youtubeUnblock 'tcp dport 443 ct original packets < 20 counter queue num 537 bypass'
nft add rule inet fw4 youtubeUnblock 'meta l4proto udp ct original packets < 9 counter queue num 537 bypass'
nft insert rule inet fw4 output 'mark and 0x8000 == 0x8000 counter accept'
echo -e "${GREEN}Правила Firewall добавлены.${NC}"

echo -e "${YELLOW}13/14: Изменение файла ruleset.uc для YouTube Unblock...${NC}"
# Изменяем строку в файле ruleset.uc для корректной работы
# Ищем строку 'meta l4proto { tcp, udp } flow offload @ft;'
# И заменяем ее на 'meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;'
sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc
echo -e "${GREEN}Файл ruleset.uc изменен.${NC}"

echo -e "${YELLOW}14/14: Перезапуск Firewall...${NC}"
# Перезапускаем firewall для применения новых правил
fw4 restart >/dev/null 2>&1
echo -e "${GREEN}Firewall перезапущен.${NC}"

echo -e "${GREEN}Установка завершена. Рекомендуется перезагрузить роутер.${NC}"
echo -e "Вы можете сделать это командой '${YELLOW}reboot${NC}'."
