#!/bin/sh

# Этот скрипт автоматизирует установку необходимых пакетов и скриптов
# для OpenWrt, включая отключение IPv6, internet-detector и podkop.
# Оптимизированная версия с улучшенной обработкой ошибок

# Устанавливаем режим выхода при первой же ошибке
set -e

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
    exit 1
}

log_progress() {
    echo -e "${BLUE}→ $1${NC}"
}

# Функция для проверки доступности сети
check_network() {
    log_progress "Проверка доступности сети..."
    if ! ping -c 1 -W 3 github.com >/dev/null 2>&1; then
        log_error "Нет доступа к интернету. Проверьте сетевое подключение."
    fi
    log_info "Сетевое подключение доступно"
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
        fi
    else
        log_error "Не удалось загрузить $description из $url"
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
    else
        log_error "Не удалось установить $description"
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
            [Yy]*) ;;
            *) log_error "Установка отменена пользователем" ;;
        esac
    fi
}

# Основная функция отключения IPv6
disable_ipv6() {
    log_progress "1/8: Отключение IPv6..."
    
    # Проверяем наличие локального скрипта
    if [ -f "./disable-ipv6-openwrt.sh" ]; then
        sh ./disable-ipv6-openwrt.sh
    else
        # Если локальный скрипт не найден, загружаем с репозитория
        safe_download "https://raw.githubusercontent.com/ciiy-dev/openwrt-install/main/disable-ipv6-openwrt.sh" \
                     "disable-ipv6-openwrt.sh" "скрипт отключения IPv6"
        chmod +x disable-ipv6-openwrt.sh
        sh ./disable-ipv6-openwrt.sh
        rm -f disable-ipv6-openwrt.sh
    fi
    log_info "IPv6 отключен"
}

# Функция обновления пакетов
update_packages() {
    log_progress "2/8: Обновление списка пакетов..."
    
    if output=$(opkg update 2>&1); then
        log_info "Список пакетов обновлен"
    else
        log_error "Не удалось обновить список пакетов"
        echo "$output"  # выведем ошибку на экран
    fi
}

# Функция установки Internet Detector
install_internet_detector() {
    log_progress "3/8: Установка Internet Detector..."
    
    # Загружаем и устанавливаем основной пакет
    safe_download "${BASE_URL_GSPOT}/internet-detector_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "internet-detector.ipk" "Internet Detector"
    safe_install "internet-detector.ipk" "Internet Detector"
    
    # Загружаем и устанавливаем LuCI интерфейс
    safe_download "${BASE_URL_GSPOT}/luci-app-internet-detector_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "luci-app-internet-detector.ipk" "LuCI интерфейс"
    safe_install "luci-app-internet-detector.ipk" "LuCI интерфейс"
    
    # Загружаем и устанавливаем языковой пакет
    safe_download "${BASE_URL_GSPOT}/luci-i18n-internet-detector-ru_${INTERNET_DETECTOR_VERSION}_all.ipk" \
                 "luci-i18n-internet-detector-ru.ipk" "русский языковой пакет"
    safe_install "luci-i18n-internet-detector-ru.ipk" "русский языковой пакет"
    
    # Запускаем и включаем службу
    log_progress "Настройка Internet Detector..."
    service internet-detector start >/dev/null 2>&1 || log_warning "Не удалось запустить Internet Detector"
    service internet-detector enable >/dev/null 2>&1 || log_warning "Не удалось включить автозапуск Internet Detector"
    
    # Перезапуск rpcd
    service rpcd restart >/dev/null 2>&1 || log_warning "Не удалось перезапустить rpcd"
    
    log_info "Internet Detector установлен и настроен"
}

# Функция установки Podkop
install_podkop() {
    log_progress "4/8: Установка Podkop..."
    
    # Скачиваем и выполняем скрипт установки podkop
    local podkop_script="/tmp/podkop_install.sh"
    if wget -O "$podkop_script" https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh >/dev/null 2>&1; then
        if echo y | sh "$podkop_script" >/dev/null 2>&1; then
            log_info "Podkop установлен"
        else
            log_warning "Возможны проблемы при установке Podkop"
        fi
        rm -f "$podkop_script"
    else
        log_warning "Не удалось загрузить скрипт установки Podkop"
    fi
}

# Функция установки зависимостей YouTube Unblock
install_youtube_deps() {
    log_progress "5/8: Установка зависимостей YouTube Unblock..."
    
    local deps="kmod-nfnetlink-queue kmod-nft-queue kmod-nf-conntrack curl"
    if opkg install $deps >/dev/null 2>&1; then
        log_info "Зависимости YouTube Unblock установлены"
    else
        log_warning "Некоторые зависимости могут быть недоступны"
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
    
    # Загружаем пакеты
    safe_download "${BASE_URL_YOUTUBE}/${youtube_package}" "youtubeUnblock.ipk" "основной пакет YouTube Unblock"
    safe_download "${BASE_URL_YOUTUBE}/${luci_package}" "luci-youtubeUnblock.ipk" "LuCI интерфейс YouTube Unblock"
    
    # Устанавливаем пакеты
    safe_install "youtubeUnblock.ipk" "основной пакет YouTube Unblock"
    safe_install "luci-youtubeUnblock.ipk" "LuCI интерфейс YouTube Unblock"
    
    log_info "YouTube Unblock установлен"
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
    else
        log_warning "Не удалось обновить файл ruleset.uc"
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
    
    log_info "Установка завершена успешно!"
}

# Основная функция
main() {
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  Автоматическая установка OpenWRT    ${NC}"
    echo -e "${GREEN}        Оптимизированная версия       ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    
    check_network
    check_architecture
    setup_temp_dir
    
    disable_ipv6
    update_packages
    install_internet_detector
    install_podkop
    install_youtube_deps
    install_youtube_unblock
    configure_firewall
    finalize_setup
    
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}    Установка завершена успешно!     ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${YELLOW}Рекомендации:${NC}"
    echo -e "• ${GREEN}Перезагрузите роутер командой: ${BLUE}reboot${NC}"
    echo -e "• ${GREEN}Проверьте веб-интерфейс после перезагрузки${NC}"
    echo -e "• ${GREEN}Протестируйте работу YouTube Unblock${NC}"
    echo ""
}

# Запуск основной функции
main "$@"
