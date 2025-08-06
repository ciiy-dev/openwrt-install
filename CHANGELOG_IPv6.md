# Изменения в скрипте отключения IPv6

## Версия 2.0 (Улучшенная)

### Что изменилось:

#### ✅ Добавлены новые эффективные команды:
1. **Более точное отключение DHCPv6:**
   - `uci set 'dhcp.lan.dhcpv6=disabled'` - явное отключение
   - `uci -q delete dhcp.lan.dhcpv6` - удаление настроек
   - `uci -q delete dhcp.lan.ra` - отключение Router Advertisement

2. **Отключение делегирования:**
   - `uci set network.lan.delegate="0"` - предотвращает делегирование IPv6 подсетей

3. **Правильный порядок выполнения:**
   - Сначала останавливаем odhcpd: `disable` → `stop`
   - Затем перезапускаем сеть: `uci commit` → `network restart`

4. **Улучшенная настройка DNS:**
   - `uci set dhcp.@dnsmasq[0].filter_aaaa='1'` - принудительная фильтрация IPv6 записей
   - `service dnsmasq restart` - перезапуск для применения

#### 🔧 Структурные улучшения:
- Пошаговые сообщения с номерами этапов
- Цветной вывод для лучшей читаемости
- Проверки и безопасное выполнение команд
- Постоянные настройки в sysctl.conf

#### 📁 Новые файлы:
- `disable-ipv6-full.sh` - базовая версия (совместимость)
- `disable-ipv6-openwrt.sh` - полнофункциональная standalone версия
- Обновлен `install_openwrt_full.sh` для использования локального скрипта

### Преимущества новой версии:

✅ **Более надежное отключение** - использует все доступные методы  
✅ **Правильная последовательность** - команды выполняются в оптимальном порядке  
✅ **Постоянные настройки** - изменения сохраняются после перезагрузки  
✅ **Улучшенная диагностика** - подробные сообщения о каждом этапе  
✅ **Совместимость** - работает с различными версиями OpenWRT  

### Команды основанные на рекомендациях пользователя:

Скрипт теперь включает все команды, предложенные пользователем:

```bash
# 1. Отключение IPv6 в сети
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'

# 2. Отключение RA и DHCPv6
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra

# 3. Отключение делегирования
uci set network.lan.delegate="0"

# 4. Удаление ULA префикса
uci -q delete network.globals.ula_prefix

# 5. Отключение odhcpd
/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop

# 6. Применение настроек
uci commit
/etc/init.d/network restart

# 7. Системное отключение IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# 8. Настройка DNS
uci set dhcp.@dnsmasq[0].filter_aaaa='1'
service dnsmasq restart
```

### Использование:

#### Автоматическая установка в составе полного пакета:
```bash
wget -O - https://raw.githubusercontent.com/ciiy-dev/openwrt-install/main/install_openwrt_full.sh | sh
```

#### Только отключение IPv6:
```bash
wget -O - https://raw.githubusercontent.com/ciiy-dev/openwrt-install/main/disable-ipv6-openwrt.sh | sh
```

### Важно:
⚠️ **После выполнения скрипта обязательно перезагрузите роутер командой `reboot`**