#!/bin/bash

if ! command -v aria2c &> /dev/null; then
    echo "aria2c не установлен. Установите его и повторите попытку."
    exit 1
fi

downloaded_file=""

download_torrent_file() {
    local torrent_file=$1
    local output_dir=$2

    if [ -f "$torrent_file" ]; then
        echo "Начинаем загрузку с файла: $torrent_file..."
        aria2c -d "$output_dir" "$torrent_file" || { echo "Ошибка загрузки файла $torrent_file!"; exit 1; }
        downloaded_file="$output_dir/$(basename "$torrent_file" .torrent)"
    else
        echo "Файл $torrent_file не найден!"
        exit 1
    fi
}

download_magnet_link() {
    local magnet_link=$1
    local output_dir=$2

    if [ -n "$magnet_link" ]; then
        echo "Начинаем загрузку с магнет-ссылки: $magnet_link..."
        local filename=$(echo "$magnet_link" | sed -n 's/.*dn=\([^&]*\).*/\1/p' | sed 's/%20/ /g')
        [ -z "$filename" ] && filename="downloaded_file"
        aria2c -d "$output_dir" --enable-dht=true --seed-time=0 --continue=true --out "$filename" "$magnet_link" || { echo "Ошибка загрузки файла с магнет-ссылки!"; exit 1; }
        downloaded_file="$output_dir/$filename"
        echo "Файл сохранён в: $downloaded_file"
    else
        echo "Магнет-ссылка не предоставлена!"
        exit 1
    fi
}

download_torrent_by_hash() {
    local torrent_hash=$1
    local output_dir=$2

    if [ -n "$torrent_hash" ]; then
        echo "Конвертируем хеш торрента в магнет-ссылку..."
        local magnet_link="magnet:?xt=urn:btih:$torrent_hash&tr=udp://tracker.openbittorrent.com:80&tr=udp://tracker.opentrackr.org:1337/announce"
        download_magnet_link "$magnet_link" "$output_dir"
    else
        echo "Хеш торрента не предоставлен!"
        exit 1
    fi
}

process_input() {
    local input="$1"
    local output_dir="$2"

    if [[ "$input" =~ ^magnet: ]]; then
        echo "Загружаем торрент по magnet-ссылке: $input"
        download_magnet_link "$input" "$output_dir"
    elif [[ "$input" =~ ^[a-fA-F0-9]{40}$ ]]; then
        echo "Загружаем торрент по хешу: $input"
        download_torrent_by_hash "$input" "$output_dir"
    else
        echo "Получено некорректное содержимое: $input."
        exit 1
    fi
}

main() {
    if [ -z "$GITHUB_WORKSPACE" ]; then
        GITHUB_WORKSPACE="$(pwd)"
        echo "Переменная GITHUB_WORKSPACE не задана. Используем текущую директорию: $GITHUB_WORKSPACE"
    fi

    local output_dir="$GITHUB_WORKSPACE/Downloads"
    mkdir -p "$output_dir"
    local input="$1"
    local file_processing="./file_processing.sh"

    if [ -z "$input" ]; then
        echo "Не указана ссылка или хеш для скачивания!"
        exit 1
    fi

    process_input "$input" "$output_dir"

    if [ -z "$downloaded_file" ] || [ ! -f "$downloaded_file" ]; then
        echo "Ошибка: файл не найден после загрузки!"
        exit 1
    fi

    echo "Скачанный файл: $downloaded_file"
    chmod +x "$file_processing"
    "$file_processing" "$downloaded_file"
}

main "$@"
