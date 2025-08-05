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
# Скачиваем и выполняем скрипт для полного отключения IPv6
# Добавляем || true, чтобы скрипт не прерывался, если disable-ipv6-full.sh выдаст "Command failed: Not found"
sh <(wget -O - https://github.com/Davoyan/router-xray-fakeip-installation/raw/main/disable-ipv6-full.sh 2>/dev/null) || true
echo -e "${GREEN}IPv6 отключен.${NC}"

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

echo -e "${YELLOW}--- Дополнительная настройка DoH (DNS over HTTPS) ---${NC}"
echo "Для настройки DNS over HTTPS выполните следующие шаги:"
echo "1. Зайдите в веб-интерфейс роутера → System → Software → Update list"
echo "2. В фильтре найдите и установите пакеты:"
echo "   - https-dns-proxy"
echo "   - luci-app-https-dns-proxy"
echo "   - luci-i18n-https-dns-proxy-ru (для русского интерфейса)"
echo "3. Перейдите в Службы → HTTPS DNS Прокси"
echo "4. Удалите стандартные конфигурации Google и Cloudflare"
echo "5. Нажмите 'Добавить', выберите провайдер: Comss DNS (RU)"
echo "6. Bootstrap DNS: 1.1.1.1,8.8.8.8"
echo "7. Сохраните и примените настройки"

echo -e "${GREEN}Установка завершена. Рекомендуется перезагрузить роутер.${NC}"
echo -e "Вы можете сделать это командой '${YELLOW}reboot${NC}'."
