#!/bin/bash

# Проверка наличия aria2c
if ! command -v aria2c &> /dev/null; then
    echo "aria2c не установлен. Установите его и повторите попытку."
    exit 1
fi

# Объявление глобальной переменной для скачанного файла
downloaded_file=""

# Функция для загрузки через файл торрента
download_torrent_file() {
    local torrent_file=$1
    local output_dir=$2

    if [ -f "$torrent_file" ]; then
        echo "Начинаем загрузку с файла: $torrent_file..."
        
        aria2c \
            -d "$output_dir" \
            "$torrent_file" || { echo "Ошибка загрузки файла $torrent_file!"; exit 1; }
        
        downloaded_file="$output_dir/$(basename "$torrent_file" .torrent)"
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

        # Извлекаем имя файла из параметра dn
        local filename=$(echo "$magnet_link" | sed -n 's/.*dn=\( [^&]* \).*/\1/p' | sed 's/%20/ /g')

        # Если имя не найдено, берем его из последней части ссылки
        if [ -z "$filename" ]; then
            filename=$(basename "$magnet_link" | cut -d'?' -f1)
        fi
        
        aria2c \
            -d "$output_dir" \
            --enable-dht=true \
            --seed-time=0 \
            --continue=true \
            --out "$filename" \
            "$magnet_link" || { echo "Ошибка загрузки файла с магнет-ссылки!"; exit 1; }
        
        downloaded_file="$output_dir/$filename"
    else
        echo "Магнет-ссылка не предоставлена!"
        exit 1
    fi
}

# Функция для загрузки через хеш торрента
download_torrent_by_hash() {
    local torrent_hash=$1
    local output_dir=$2

    if [ -n "$torrent_hash" ]; then
        echo "Конвертируем хеш торрента в магнет-ссылку..."
        magnet_link="magnet:?xt=urn:btih:$torrent_hash"
        download_magnet_link "$magnet_link" "$output_dir"
    else
        echo "Хеш торрента не предоставлен!"
        exit 1
    fi
}

# Главная функция
main() {
    local output_dir="$GITHUB_WORKSPACE/Downloads"
    local torrent_url="$1"
    local torrent_hash="$2"
    local file_processing="./file_processing.sh"

    if [ -z "$torrent_url" ] && [ -z "$torrent_hash" ]; then
        echo "Не указана ссылка или хеш для скачивания!"
        exit 1
    fi

    if [ -z "$GITHUB_WORKSPACE" ]; then
        echo "Переменная GITHUB_WORKSPACE не установлена!"
        exit 1
    fi

    mkdir -p "$output_dir"

    # Скачиваем через магнет-ссылку или файл торрента
    if [[ "$torrent_url" =~ ^magnet: ]]; then
        download_magnet_link "$torrent_url" "$output_dir"
    elif [[ -f "$torrent_url" ]]; then
        download_torrent_file "$torrent_url" "$output_dir"
    fi

    # Если указан хеш, скачиваем через хеш
    if [ -n "$torrent_hash" ]; then
        download_torrent_by_hash "$torrent_hash" "$output_dir"
    fi

    # Проверка наличия загруженного файла
    if [ -z "$downloaded_file" ] || [ ! -f "$downloaded_file" ]; then
        echo "Ошибка: файл не найден после загрузки!"
        exit 1
    fi

    echo "Скачанный файл: $downloaded_file"

    chmod +x "$file_processing"
    "$file_processing" "$downloaded_file"
}

# Запуск главной функции с удалением временных файлов при выходе из скрипта.
trap 'if [ -f "$downloaded_file" ]; then rm -f "$downloaded_file"; fi' EXIT
main "$@"
