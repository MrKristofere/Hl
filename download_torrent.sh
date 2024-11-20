#!/bin/bash

# Функция для загрузки через файл торрента
download_torrent_file() {
    local torrent_file=$1
    local output_dir=$2

    if [ -f "$torrent_file" ]; then
        echo "Начинаем загрузку с файла: $torrent_file..."
        aria2c -d "$output_dir" "$torrent_file" || { echo "Ошибка загрузки файла!"; exit 1; }
        find ~/.cache/aria2
    else
        echo "Файл $torrent_file не найден!"
        exit 1
    fi
}

create_dht_dat() {
    mkdir -p $HOME/.cache/aria2
    chmod 755 $HOME/.cache/aria2
    if ! [ -e $HOME/.cache/aria2/dht.dat ]; then
    # hide false error: Exception caught while loading DHT routing table
    # https://github.com/aria2/aria2/issues/1253
    # based on aria2/src/DHTRoutingTableDeserializer.cc
    hex="a1 a2"
    hex+="02" # format
    hex+="00 00 00" # reserved
    hex+="00 03" # version
    hex+=$(printf "%016x\n" $(date --utc +%s)) # time
    hex+="00 00 00 00 00 00 00 00" # localnode
    hex+=$(dd if=/dev/urandom bs=1 count=40 status=none | sha1sum | cut -c1-40) # localnode ID
    hex+="00 00 00 00" # reserved
    hex+="00 00 00 00" # num_nodes uint32_t
    hex+="00 00 00 00" # reserved
    # 56 bytes
    mkdir -p $HOME/.cache/aria2
    echo $hex | xxd -r -p >$HOME/.cache/aria2/dht.dat
  fi
}

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

# Главная функция
main() {
    # Параметры
    local output_dir="$GITHUB_WORKSPACE/Downloads"  # Папка для скачивания в GitHub Actions
    local torrent_url="$1"  # Получаем ссылку через параметры скрипта
    local file_processing="./file_processing.sh"  # Путь к следующему скрипту

    # Проверка, что передана ссылка
    if [ -z "$torrent_url" ]; then
        echo "Не указана ссылка для скачивания!"
        exit 1
    fi

    # Создание директории для загрузок, если она не существует
    mkdir -p "$output_dir"

    # Проверка, является ли переданная ссылка магнет-ссылкой
    local downloaded_file=""
    if [[ "$torrent_url" =~ ^magnet: ]]; then
        download_magnet_link "$torrent_url" "$output_dir"
        downloaded_file="$output_dir/downloaded_file"
    elif [[ -f "$torrent_url" ]]; then
        download_torrent_file "$torrent_url" "$output_dir"
        downloaded_file=$(find "$output_dir" -type f | head -n 1)
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
