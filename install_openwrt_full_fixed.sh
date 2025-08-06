#!/bin/sh

# Этот скрипт автоматизирует установку необходимых пакетов и скриптов
# для OpenWrt, включая отключение IPv6, internet-detector и podkop.
# Оптимизированная версия с улучшенной обработкой ошибок

# ВАЖНО: Убираем set -e для более мягкой обработки ошибок
# set -e вызывает немедленное завершение при любой ошибке

# ANSI escape codes for colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация пакетов
INTERNET_DETECTOR_VERSION="1.6.1-r1"
YOUTUBE_UNBLOCK_VERSION="1.0.0"
TEMP_DIR="/tmp/openwrt_install"

# URLs для загрузки пакетов
BASE_URL_GSPOT="https://github.com/gSpotx2f/packages-openwrt/raw/master/current"
BASE_URL_YOUTUBE="https://github.com/Waujito/youtubeUnblock/releases/download/v${YOUTUBE_UNBLOCK_VERSION}"

# Функция для логирования
log_info() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    # Не выходим немедленно, продолжаем выполнение
}

log_progress() {
    echo -e "${BLUE}→ $1${NC}"
}

# Функция для проверки доступности сети
check_network() {
    log_progress "Проверка доступности сети..."
    if ! ping -c 1 -W 3 github.com >/dev/null 2>&1; then
        log_error "Нет доступа к интернету. Проверьте сетевое подключение."
        return 1
    fi
    log_info "Сетевое подключение доступно"
    return 0
}

# Функция для создания временной директории
setup_temp_dir() {
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
}

# Функция для очистки временных файлов
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Обработчик сигналов для очистки
trap cleanup EXIT INT TERM

# Функция для безопасной загрузки файла
safe_download() {
    local url="$1"
    local filename="$2"
    local description="$3"
    
    log_progress "Загрузка $description..."
    if wget --no-check-certificate -O "$filename" "$url" >/dev/null 2>&1; then
        if [ -f "$filename" ] && [ -s "$filename" ]; then
            log_info "$description загружен"
            return 0
        else
            log_error "Загруженный файл $description пуст или поврежден"
            return 1
        fi
    else
        log_error "Не удалось загрузить $description из $url"
        return 1
    fi
}

# Функция для безопасной установки пакета
safe_install() {
    local package_file="$1"
    local description="$2"
    
    log_progress "Установка $description..."
    if opkg install "$package_file" >/dev/null 2>&1; then
        log_info "$description установлен"
        rm -f "$package_file"
        return 0
    else
        log_error "Не удалось установить $description"
        rm -f "$package_file" 2>/dev/null || true
        return 1
    fi
}

# Функция для проверки архитектуры
check_architecture() {
    local arch=$(opkg print-architecture 2>/dev/null | grep -o 'aarch64_cortex-a53' | head -1)
    if [ -z "$arch" ]; then
        log_warning "Архитектура aarch64_cortex-a53 не найдена. Проверьте совместимость."
        log_warning "Доступные архитектуры:"
        opkg print-architecture
        read -p "Продолжить установку? (y/N): " confirm
        case $confirm in
            [Yy]*) return 0 ;;
            *) log_error "Установка отменена пользователем"; return 1 ;;
        esac
    fi
    return 0
}

# Основная функция отключения IPv6
disable_ipv6() {
    log_progress "1/8: Отключение IPv6..."
    
    # Проверяем наличие локального скрипта
    if [ -f "./disable-ipv6-openwrt.sh" ]; then
        sh ./disable-ipv6-openwrt.sh
    else
        # Если локальный скрипт не найден, загружаем с репозитория
        if safe_download "https://raw.githubusercontent.com/ciiy-dev/openwrt-install/main/disable-ipv6-openwrt.sh" \
                     "disable-ipv6-openwrt.sh" "скрипт отключения IPv6"; then
            chmod +x disable-ipv6-openwrt.sh
            sh ./disable-ipv6-openwrt.sh
            rm -f disable-ipv6-openwrt.sh
        else
            log_warning "Не удалось загрузить скрипт отключения IPv6, пропускаем этот шаг"
            return 1
        fi
    fi
    log_info "IPv6 отключен"
    return 0
}

# Функция обновления пакетов
update_packages() {
    log_progress "2/8: Обновление списка пакетов..."
    
    # Ожидаем восстановления сети после перезапуска сетевой службы
    log_info "Ожидание восстановления сетевого подключения..."
    sleep 5
    
    # Проверяем доступность интернета перед обновлением
    local retries=3
    local retry_count=0
    
    while [ $retry_count -lt $retries ]; do
        if ping -c 1 -W 5 openwrt.org >/dev/null 2>&1; then
            log_info "Сетевое подключение восстановлено"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $retries ]; then
                log_info "Попытка $retry_count/$retries: Ожидание восстановления сети..."
                sleep 3
            else
                log_warning "Не удалось дождаться восстановления сети, продолжаем..."
            fi
        fi
    done
    
    # Попытка обновления пакетов
    retry_count=0
    local success=0
    
    while [ $retry_count -lt $retries ] && [ $success -eq 0 ]; do
        retry_count=$((retry_count + 1))
        log_info "Попытка обновления пакетов $retry_count/$retries..."
        
        output=$(opkg update 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ] || echo "$output" | grep -q -E "(Updated list|Signature check passed)"; then
            log_info "Список пакетов успешно обновлен"
            success=1
        else
            log_warning "Попытка $retry_count не удалась"
            if [ $retry_count -lt $retries ]; then
                log_info "Ожидание перед следующей попыткой..."
                sleep 5
            fi
        fi
    done
    
    if [ $success -eq 0 ]; then
        log_warning "Не удалось обновить список пакетов после $retries попыток"
        log_warning "Вывод последней попытки:"
        echo "$output"
        log_warning "Продолжаем установку, но некоторые пакеты могут быть недоступны"
        return 1
    fi
    return 0
}

# Функция установки Internet Detector
install_internet_detector() {
    log_progress "3/8: Установка Internet Detector..."
    
    local all_success=0
    
    # Загружаем и устанавливаем основной пакет
    if safe_download "${BASE_URL_GSPOT}/internet-detector_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "internet-detector.ipk" "Internet Detector"; then
        if safe_install "internet-detector.ipk" "Internet Detector"; then
            all_success=1
        fi
    fi
    
    # Загружаем и устанавливаем LuCI интерфейс
    if safe_download "${BASE_URL_GSPOT}/luci-app-internet-detector_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "luci-app-internet-detector.ipk" "LuCI интерфейс"; then
        safe_install "luci-app-internet-detector.ipk" "LuCI интерфейс"
    fi
    
    # Загружаем и устанавливаем языковой пакет
    if safe_download "${BASE_URL_GSPOT}/luci-i18n-internet-detector-ru_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "luci-i18n-internet-detector-ru.ipk" "русский языковой пакет"; then
        safe_install "luci-i18n-internet-detector-ru.ipk" "русский языковой пакет"
    fi
    
    if [ $all_success -eq 1 ]; then
        # Запускаем и включаем службу
        log_progress "Настройка Internet Detector..."
        service internet-detector start >/dev/null 2>&1 || log_warning "Не удалось запустить Internet Detector"
        service internet-detector enable >/dev/null 2>&1 || log_warning "Не удалось включить автозапуск Internet Detector"
        
        # Перезапуск rpcd
        service rpcd restart >/dev/null 2>&1 || log_warning "Не удалось перезапустить rpcd"
        
        log_info "Internet Detector установлен и настроен"
        return 0
    else
        log_warning "Internet Detector не установлен из-за ошибок загрузки"
        return 1
    fi
}

# Функция установки Podkop
install_podkop() {
    log_progress "4/8: Установка Podkop..."
    
    # Скачиваем и выполняем скрипт установки podkop
    local podkop_script="/tmp/podkop_install.sh"
    if wget -O "$podkop_script" https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh >/dev/null 2>&1; then
        if echo y | sh "$podkop_script" >/dev/null 2>&1; then
            log_info "Podkop установлен"
            rm -f "$podkop_script"
            return 0
        else
            log_warning "Возможны проблемы при установке Podkop"
            rm -f "$podkop_script"
            return 1
        fi
    else
        log_warning "Не удалось загрузить скрипт установки Podkop"
        return 1
    fi
}

# Функция установки зависимостей YouTube Unblock
install_youtube_deps() {
    log_progress "5/8: Установка зависимостей YouTube Unblock..."
    
    local deps="kmod-nfnetlink-queue kmod-nft-queue kmod-nf-conntrack curl"
    if opkg install $deps >/dev/null 2>&1; then
        log_info "Зависимости YouTube Unblock установлены"
        return 0
    else
        log_warning "Некоторые зависимости могут быть недоступны"
        return 1
    fi
}

# Функция установки YouTube Unblock
install_youtube_unblock() {
    log_progress "6/8: Установка YouTube Unblock..."
    
    # Определяем архитектуру для YouTube Unblock
    local arch="aarch64_cortex-a53"
    
    # Пакеты для загрузки
    local youtube_package="youtubeUnblock-${YOUTUBE_UNBLOCK_VERSION}-10-f37c3dd-${arch}-openwrt-23.05.ipk"
    local luci_package="luci-app-youtubeUnblock-${YOUTUBE_UNBLOCK_VERSION}-10-f37c3dd.ipk"
    
    local success=0
    
    # Загружаем пакеты
    if safe_download "${BASE_URL_YOUTUBE}/${youtube_package}" "youtubeUnblock.ipk" "основной пакет YouTube Unblock"; then
        if safe_install "youtubeUnblock.ipk" "основной пакет YouTube Unblock"; then
            success=1
        fi
    fi
    
    if safe_download "${BASE_URL_YOUTUBE}/${luci_package}" "luci-youtubeUnblock.ipk" "LuCI интерфейс YouTube Unblock"; then
        safe_install "luci-youtubeUnblock.ipk" "LuCI интерфейс YouTube Unblock"
    fi
    
    if [ $success -eq 1 ]; then
        log_info "YouTube Unblock установлен"
        return 0
    else
        log_warning "YouTube Unblock не установлен из-за ошибок"
        return 1
    fi
}

# Функция настройки Firewall для YouTube Unblock
configure_firewall() {
    log_progress "7/8: Настройка Firewall для YouTube Unblock..."
    
    # Добавляем правила в firewall
    if nft add chain inet fw4 youtubeUnblock '{ type filter hook postrouting priority mangle - 1; policy accept; }' 2>/dev/null &&
       nft add rule inet fw4 youtubeUnblock 'tcp dport 443 ct original packets < 20 counter queue num 537 bypass' 2>/dev/null &&
       nft add rule inet fw4 youtubeUnblock 'meta l4proto udp ct original packets < 9 counter queue num 537 bypass' 2>/dev/null &&
       nft insert rule inet fw4 output 'mark and 0x8000 == 0x8000 counter accept' 2>/dev/null; then
        log_info "Правила Firewall добавлены"
    else
        log_warning "Некоторые правила Firewall не удалось добавить (возможно уже существуют)"
    fi
    
    # Изменяем файл ruleset.uc
    log_progress "Настройка ruleset.uc..."
    if sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc; then
        log_info "Файл ruleset.uc обновлен"
        return 0
    else
        log_warning "Не удалось обновить файл ruleset.uc"
        return 1
    fi
}

# Функция финальной настройки
finalize_setup() {
    log_progress "8/8: Финальная настройка..."
    
    # Перезапуск firewall
    if fw4 restart >/dev/null 2>&1; then
        log_info "Firewall перезапущен"
    else
        log_warning "Не удалось перезапустить Firewall"
    fi
    
    log_info "Установка завершена!"
    return 0
}

# Основная функция
main() {
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  Автоматическая установка OpenWRT    ${NC}"
    echo -e "${GREEN}        Оптимизированная версия       ${NC}"
    echo -e "${GREEN}        (Исправленная версия)         ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    
    local errors=0
    
    if ! check_network; then
        echo -e "${RED}Критическая ошибка: нет сетевого подключения${NC}"
        exit 1
    fi
    
    if ! check_architecture; then
        errors=$((errors + 1))
    fi
    
    setup_temp_dir
    
    disable_ipv6 || errors=$((errors + 1))
    update_packages || errors=$((errors + 1))
    install_internet_detector || errors=$((errors + 1))
    install_podkop || errors=$((errors + 1))
    install_youtube_deps || errors=$((errors + 1))
    install_youtube_unblock || errors=$((errors + 1))
    configure_firewall || errors=$((errors + 1))
    finalize_setup || errors=$((errors + 1))
    
    echo ""
    echo -e "${GREEN}======================================${NC}"
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}    Установка завершена успешно!     ${NC}"
    else
        echo -e "${YELLOW}  Установка завершена с ошибками:    ${NC}"
        echo -e "${YELLOW}       Ошибок: $errors               ${NC}"
    fi
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${YELLOW}Рекомендации:${NC}"
    echo -e "• ${GREEN}Перезагрузите роутер командой: ${BLUE}reboot${NC}"
    echo -e "• ${GREEN}Проверьте веб-интерфейс после перезагрузки${NC}"
    echo -e "• ${GREEN}Протестируйте работу установленных компонентов${NC}"
    echo ""
}

# Запуск основной функции
main "$@"