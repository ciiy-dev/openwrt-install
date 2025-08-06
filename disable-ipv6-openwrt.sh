#!/bin/sh

# Скрипт для полного отключения IPv6 в OpenWRT
# Основан на более эффективных командах для отключения IPv6
# Версия: 2.0 (улучшенная)

# ANSI escape codes for colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Скрипт отключения IPv6 в OpenWRT   ${NC}"
echo -e "${GREEN}        Улучшенная версия 2.0        ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

echo -e "${YELLOW}1. Отключение поддержки IPv6 в локальной сети и от провайдера...${NC}"
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
echo -e "${GREEN}✓ IPv6 отключен в настройках сети${NC}"

echo -e "${YELLOW}2. Отключение RA и DHCPv6 для предотвращения раздачи IPv6 адресов...${NC}"
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
echo -e "${GREEN}✓ RA и DHCPv6 отключены${NC}"

echo -e "${YELLOW}3. Отключение делегирования локальной сети...${NC}"
uci set network.lan.delegate="0"
echo -e "${GREEN}✓ Делегирование отключено${NC}"

echo -e "${YELLOW}4. Удаление префикса IPv6 ULA...${NC}"
uci -q delete network.globals.ula_prefix
echo -e "${GREEN}✓ ULA префикс удален${NC}"

echo -e "${YELLOW}5. Отключение службы odhcpd...${NC}"
/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop
echo -e "${GREEN}✓ Служба odhcpd остановлена и отключена${NC}"

echo -e "${YELLOW}6. Сохранение изменений и перезапуск сетевой службы...${NC}"
uci commit
/etc/init.d/network restart
echo -e "${GREEN}✓ Настройки сохранены, сетевая служба перезапущена${NC}"

echo -e "${YELLOW}7. Полное отключение IPv6 в системе...${NC}"
sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
echo -e "${GREEN}✓ IPv6 отключен на системном уровне${NC}"

echo -e "${YELLOW}8. Настройка dnsmasq для возврата только IPv4 записей...${NC}"
uci set dhcp.@dnsmasq[0].filter_aaaa='1'
service dnsmasq restart
echo -e "${GREEN}✓ DNS настроен для работы только с IPv4${NC}"

echo -e "${YELLOW}9. Добавление постоянных настроек в sysctl.conf...${NC}"
# Удаляем старые записи если есть
sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf

# Добавляем новые записи
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.conf
echo -e "${GREEN}✓ Постоянные настройки добавлены в sysctl.conf${NC}"

echo -e "${YELLOW}10. Применение sysctl настроек...${NC}"
sysctl -p >/dev/null 2>&1
echo -e "${GREEN}✓ Настройки sysctl применены${NC}"

echo -e "${YELLOW}11. Очистка IPv6 записей из resolv.conf...${NC}"
sed -i '/::1/d' /etc/resolv.conf
echo -e "${GREEN}✓ IPv6 записи удалены из resolv.conf${NC}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}       IPv6 успешно отключен!        ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Важная информация:${NC}"
echo -e "• ${RED}Для полного применения всех изменений необходимо перезагрузить роутер${NC}"
echo -e "• ${YELLOW}Команда для перезагрузки: ${GREEN}reboot${NC}"
echo -e "• ${YELLOW}После перезагрузки IPv6 будет полностью отключен${NC}"
echo ""
echo -e "${GREEN}Все настройки применены успешно!${NC}"