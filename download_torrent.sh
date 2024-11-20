#!/bin/bash

# Функция для загрузки через файл торрента
download_torrent_file() {
    local torrent_file=$1
    local output_dir=$2

    if [ -f "$torrent_file" ]; then
        echo "Начинаем загрузку с файла: $torrent_file..."
        aria2c -d "$output_dir" "$torrent_file" || { echo "Ошибка загрузки файла!"; exit 1; }
    else
        echo "Файл $torrent_file не найден!"
        exit 1
    fi
}

# Функция для загрузки через магнет-ссылку
download_magnet_link() {
    local magnet_link=$1
    local output_dir=$2

    if [ -n "$magnet_link" ]; then
        echo "Начинаем загрузку с магнет-ссылки: $magnet_link..."
        aria2c \
          -d "$output_dir" \
          --out "$downloaded_file" \
          --enable-dht=true \
          --dht-entry-point=router.bittorrent.com:6881 \
          --dht-entry-point=dht.transmissionbt.com:6881 \
          --dht-entry-point=router.utorrent.com:6881 \
          --dht-entry-point=dht.vuze.com:6881 \
          --dht-entry-point=dht.libtorrent.org:25401 \
          --seed-time=0 \
          --continue=true \
          "$magnet_link" || { echo "Ошибка загрузки файла!"; exit 1; }
    else
        echo "Магнет-ссылка не предоставлена!"
        exit 1
    fi
}

# Функция для загрузки по хешу торрента
download_torrent_by_hash() {
    local torrent_hash=$1
    local output_dir=$2

    if [ -n "$torrent_hash" ]; then
        echo "Начинаем загрузку с хеша торрента: $torrent_hash..."
        magnet_link="magnet:?xt=urn:btih:$torrent_hash"  # Генерируем магнет-ссылку
        download_magnet_link "$magnet_link" "$output_dir"  # Загружаем по магнет-ссылке
    else
        echo "Хеш торрента не предоставлен!"
        exit 1
    fi
}

# Главная функция
main() {
    # Параметры
    local output_dir="$GITHUB_WORKSPACE/Downloads"  # Папка для скачивания в GitHub Actions
    local torrent_url="$1"  # Получаем ссылку через параметры скрипта
    local torrent_hash="$2"  # Получаем хеш торрента через параметры
    local file_processing="./file_processing.sh"  # Путь к следующему скрипту

    # Проверка, что передана ссылка или хеш
    if [ -z "$torrent_url" ] && [ -z "$torrent_hash" ]; then
        echo "Не указана ссылка или хеш для скачивания!"
        exit 1
    fi

    # Создание директории для загрузок, если она не существует
    mkdir -p "$output_dir"

    # Проверка, является ли переданная ссылка магнет-ссылкой или файлом
    local downloaded_file=""
    if [[ "$torrent_url" =~ ^magnet: ]]; then
        download_magnet_link "$torrent_url" "$output_dir"
        downloaded_file="$output_dir/downloaded_file"
    elif [[ -f "$torrent_url" ]]; then
        download_torrent_file "$torrent_url" "$output_dir"
        downloaded_file=$(find "$output_dir" -type f | head -n 1)
    elif [[ -n "$torrent_hash" ]]; then
        download_torrent_by_hash "$torrent_hash" "$output_dir"
        downloaded_file="$output_dir/downloaded_file"
    else
        echo "Неверная ссылка или файл не существует!"
        exit 1
    fi

    # Проверка существования файла
    if [ ! -f "$downloaded_file" ]; then
        echo "Ошибка: файл не найден после загрузки!"
        exit 1
    fi

    echo "Скачанный файл: $downloaded_file"

    # Запуск следующего скрипта с передачей пути к файлу
    chmod +x "$file_processing"
    "$file_processing" "$downloaded_file"
}

# Запуск главной функции
main "$@"
