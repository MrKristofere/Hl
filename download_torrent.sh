#!/bin/bash

# Функция для загрузки через файл торрента
download_torrent_file() {
    local torrent_file=$1
    local output_dir=$2

    if [ -f "$torrent_file" ]; then
        echo "Начинаем загрузку с файла: $torrent_file..."
        aria2c -d "$output_dir" "$torrent_file"
        echo "$output_dir"
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
        aria2c -d "$output_dir" "$magnet_link"
        echo "$output_dir"
    else
        echo "Магнет-ссылка не предоставлена!"
        exit 1
    fi
}

# Главная функция
main() {
    # Параметры
    local output_dir="$GITHUB_WORKSPACE/Downloads"  # Папка для скачивания в GitHub Actions
    local torrent_url="$1"  # Получаем ссылку через параметры скрипта
    local next_script="./next_script.sh"  # Путь к следующему скрипту

    # Проверка, что передана ссылка
    if [ -z "$torrent_url" ]; then
        echo "Не указана ссылка для скачивания!"
        exit 1
    fi

    # Создание директории для загрузок, если она не существует
    mkdir -p "$output_dir"

    # Проверка, является ли переданная ссылка магнет-ссылкой
    local downloaded_path=""
    if [[ "$torrent_url" =~ ^magnet: ]]; then
        downloaded_path=$(download_magnet_link "$torrent_url" "$output_dir")
    elif [[ -f "$torrent_url" ]]; then
        downloaded_path=$(download_torrent_file "$torrent_url" "$output_dir")
    else
        echo "Неверная ссылка или файл не существует!"
        exit 1
    fi

    # Определение скачанного файла
    local downloaded_file=$(find "$downloaded_path" -type f | head -n 1)
    if [ -z "$downloaded_file" ]; then
        echo "Ошибка: файл не найден после загрузки!"
        exit 1
    fi

    echo "Скачанный файл: $downloaded_file"

    # Запуск следующего скрипта с передачей пути к файлу
    if [ -x "$next_script" ]; then
        "$next_script" "$downloaded_file"
    else
        echo "Следующий скрипт ($next_script) не найден или не является исполняемым!"
        exit 1
    fi
}

# Запуск главной функции
main "$@"
