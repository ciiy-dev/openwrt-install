#!/bin/sh

# Скрипт для полного отключения IPv6 в OpenWRT
# Оптимизированная версия 2.1 с улучшенной обработкой ошибок
# Основан на более эффективных командах для отключения IPv6

# ВАЖНО: НЕ используем set -e для корректной обработки ошибок
# set -e может вызвать преждевременное завершение при некритичных ошибках

# ANSI escape codes for colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для логирования
log_info() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

log_progress() {
    echo -e "${BLUE}→ $1${NC}"
}

# Функция для проверки команды UCI
check_uci() {
    if ! command -v uci >/dev/null 2>&1; then
        log_error "Команда uci не найдена. Убедитесь, что выполняете скрипт на OpenWRT"
    fi
}

# Функция для безопасного выполнения UCI команд
safe_uci() {
    local action="$1"
    local setting="$2"
    local value="$3"
    
    case "$action" in
        "set")
            if uci set "$setting=$value" 2>/dev/null; then
                return 0
            else
                log_warning "Не удалось установить $setting=$value"
                return 1
            fi
            ;;
        "delete")
            if uci -q delete "$setting" 2>/dev/null; then
                return 0
            else
                # Удаление несуществующего параметра не является ошибкой
                return 0
            fi
            ;;
    esac
}

# Функция для отключения сетевых настроек IPv6
disable_network_ipv6() {
    log_progress "Отключение поддержки IPv6 в локальной сети и от провайдера..."
    
    local success=0
    safe_uci "set" "network.lan.ipv6" "0" && success=$((success+1))
    safe_uci "set" "network.wan.ipv6" "0" && success=$((success+1))
    safe_uci "set" "dhcp.lan.dhcpv6" "disabled" && success=$((success+1))
    
    if [ $success -gt 0 ]; then
        log_info "IPv6 отключен в настройках сети ($success/3 настроек)"
    else
        log_warning "Не удалось изменить базовые сетевые настройки IPv6"
    fi
}

# Функция для отключения DHCP и RA
disable_dhcp_ra() {
    log_progress "Отключение RA и DHCPv6 для предотвращения раздачи IPv6 адресов..."
    
    safe_uci "delete" "dhcp.lan.dhcpv6"
    safe_uci "delete" "dhcp.lan.ra"
    
    log_info "RA и DHCPv6 отключены"
}

# Функция для отключения делегирования
disable_delegation() {
    log_progress "Отключение делегирования локальной сети..."
    
    if safe_uci "set" "network.lan.delegate" "0"; then
        log_info "Делегирование отключено"
    else
        log_warning "Не удалось отключить делегирование"
    fi
}

# Функция для удаления ULA префикса
remove_ula_prefix() {
    log_progress "Удаление префикса IPv6 ULA..."
    
    safe_uci "delete" "network.globals.ula_prefix"
    log_info "ULA префикс удален"
}

# Функция для остановки odhcpd
disable_odhcpd() {
    log_progress "Отключение службы odhcpd..."
    
    local success=0
    if /etc/init.d/odhcpd disable >/dev/null 2>&1; then
        success=$((success+1))
    fi
    if /etc/init.d/odhcpd stop >/dev/null 2>&1; then
        success=$((success+1))
    fi
    
    if [ $success -eq 2 ]; then
        log_info "Служба odhcpd остановлена и отключена"
    elif [ $success -eq 1 ]; then
        log_warning "odhcpd частично отключен"
    else
        log_warning "Не удалось полностью отключить odhcpd"
    fi
}

# Функция для применения настроек сети
apply_network_settings() {
    log_progress "Сохранение изменений и перезапуск сетевой службы..."
    
    if uci commit 2>/dev/null; then
        log_info "Настройки UCI сохранены"
    else
        log_warning "Не удалось сохранить некоторые настройки UCI"
    fi
    
    if /etc/init.d/network restart >/dev/null 2>&1; then
        log_info "Сетевая служба перезапущена"
        # Даем время сети на перезапуск
        sleep 2
    else
        log_warning "Не удалось перезапустить сетевую службу"
    fi
}

# Функция для системного отключения IPv6
disable_system_ipv6() {
    log_progress "Полное отключение IPv6 в системе..."
    
    local success=0
    
    # Применяем настройки sysctl
    for setting in "net.ipv6.conf.all.disable_ipv6=1" \
                   "net.ipv6.conf.default.disable_ipv6=1" \
                   "net.ipv6.conf.lo.disable_ipv6=1"; do
        if sysctl -w "$setting" >/dev/null 2>&1; then
            success=$((success+1))
        fi
    done
    
    # Дополнительная установка через /proc
    if echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null; then
        success=$((success+1))
    fi
    
    if [ $success -gt 3 ]; then
        log_info "IPv6 отключен на системном уровне"
    else
        log_warning "Частичное отключение IPv6 на системном уровне"
    fi
}

# Функция для настройки DNS
configure_dns() {
    log_progress "Настройка dnsmasq для возврата только IPv4 записей..."
    
    if safe_uci "set" "dhcp.@dnsmasq[0].filter_aaaa" "1"; then
        if service dnsmasq restart >/dev/null 2>&1; then
            log_info "DNS настроен для работы только с IPv4"
        else
            log_warning "DNS настроен, но перезапуск dnsmasq не удался"
        fi
    else
        log_warning "Не удалось настроить фильтрацию IPv6 в DNS"
    fi
}

# Функция для создания постоянных настроек
create_persistent_settings() {
    log_progress "Добавление постоянных настроек в sysctl.conf..."
    
    local sysctl_file="/etc/sysctl.conf"
    local temp_file="/tmp/sysctl_temp"
    
    # Создаем резервную копию если файл существует
    if [ -f "$sysctl_file" ]; then
        cp "$sysctl_file" "${sysctl_file}.backup" 2>/dev/null || true
    fi
    
    # Удаляем старые записи IPv6
    if [ -f "$sysctl_file" ]; then
        grep -v "^net.ipv6.conf.*disable_ipv6=" "$sysctl_file" > "$temp_file" 2>/dev/null || true
    else
        touch "$temp_file"
    fi
    
    # Добавляем новые записи
    cat >> "$temp_file" << EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
    
    # Заменяем файл
    if mv "$temp_file" "$sysctl_file" 2>/dev/null; then
        log_info "Постоянные настройки добавлены в sysctl.conf"
    else
        log_warning "Не удалось создать постоянные настройки"
        rm -f "$temp_file" 2>/dev/null || true
    fi
}

# Функция для применения sysctl настроек
apply_sysctl() {
    log_progress "Применение sysctl настроек..."
    
    if sysctl -p >/dev/null 2>&1; then
        log_info "Настройки sysctl применены"
    else
        log_warning "Не удалось применить все настройки sysctl"
    fi
}

# Функция для очистки IPv6 из resolv.conf
clean_resolv_conf() {
    log_progress "Очистка IPv6 записей из resolv.conf..."
    
    local resolv_file="/etc/resolv.conf"
    if [ -f "$resolv_file" ]; then
        if sed -i '/::1/d' "$resolv_file" 2>/dev/null; then
            log_info "IPv6 записи удалены из resolv.conf"
        else
            log_warning "Не удалось очистить resolv.conf"
        fi
    else
        log_info "Файл resolv.conf не найден (это нормально)"
    fi
}

# Функция для проверки статуса IPv6
check_ipv6_status() {
    log_progress "Проверка статуса IPv6..."
    
    local ipv6_enabled=0
    
    # Проверяем sysctl настройки
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" = "1" ]; then
        log_info "IPv6 отключен в sysctl"
    else
        log_warning "IPv6 все еще может быть активен в sysctl"
        ipv6_enabled=1
    fi
    
    # Проверяем интерфейсы
    if ip -6 addr show 2>/dev/null | grep -q "inet6" && [ $ipv6_enabled -eq 0 ]; then
        log_warning "Обнаружены IPv6 адреса на интерфейсах (возможно временные)"
    fi
    
    return $ipv6_enabled
}

# Основная функция
main() {
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  Скрипт отключения IPv6 в OpenWRT   ${NC}"
    echo -e "${GREEN}     Оптимизированная версия 2.1     ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    
    # Проверки перед началом
    check_uci
    
    # Выполняем отключение IPv6 поэтапно
    disable_network_ipv6
    disable_dhcp_ra
    disable_delegation
    remove_ula_prefix
    disable_odhcpd
    apply_network_settings
    disable_system_ipv6
    configure_dns
    create_persistent_settings
    apply_sysctl
    clean_resolv_conf
    
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}       IPv6 успешно отключен!        ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    
    # Проверяем результат
    if check_ipv6_status; then
        log_warning "IPv6 может быть не полностью отключен"
    fi
    
    echo -e "${YELLOW}Важная информация:${NC}"
    echo -e "• ${RED}Для полного применения всех изменений необходимо перезагрузить роутер${NC}"
    echo -e "• ${YELLOW}Команда для перезагрузки: ${GREEN}reboot${NC}"
    echo -e "• ${YELLOW}После перезагрузки IPv6 будет полностью отключен${NC}"
    echo ""
    echo -e "${GREEN}Все настройки применены успешно!${NC}"
}

# Запуск основной функции
main "$@"