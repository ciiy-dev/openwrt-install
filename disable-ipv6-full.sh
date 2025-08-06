#!/bin/sh

# Скрипт для полного отключения IPv6 в OpenWRT
# Улучшенная версия с более эффективными командами

echo "Начинаем процесс отключения IPv6 в OpenWRT..."

echo "1. Отключение поддержки IPv6 в локальной сети и от провайдера..."
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'

echo "2. Отключение RA и DHCPv6 для предотвращения раздачи IPv6 адресов..."
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra

echo "3. Отключение делегирования локальной сети..."
uci set network.lan.delegate="0"

echo "4. Удаление префикса IPv6 ULA..."
uci -q delete network.globals.ula_prefix

echo "5. Отключение odhcpd..."
/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop

echo "6. Сохранение изменений и перезапуск сети..."
uci commit
/etc/init.d/network restart

echo "7. Полное отключение IPv6 в системе..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo "8. Настройка dnsmasq для возврата только IPv4 записей..."
uci set dhcp.@dnsmasq[0].filter_aaaa='1'
service dnsmasq restart

echo "9. Добавление постоянных настроек в sysctl.conf..."
# Удаляем старые записи если есть
sed -i '/^net.ipv6.conf.all.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.default.disable_ipv6=/d' /etc/sysctl.conf
sed -i '/^net.ipv6.conf.lo.disable_ipv6=/d' /etc/sysctl.conf

# Добавляем новые записи
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.conf

echo "10. Применение sysctl настроек..."
sysctl -p

echo "11. Очистка IPv6 записей из resolv.conf..."
sed -i '/::1/d' /etc/resolv.conf

echo "IPv6 успешно отключен!"
printf "\033[32;1mВажно! Для полного применения всех изменений необходимо перезагрузить роутер командой 'reboot'\033[0m\n"