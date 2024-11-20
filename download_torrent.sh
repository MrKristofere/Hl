#!/bin/bash

# Проверка, передан ли аргумент
if [ -z "$1" ]; then
  echo "Ошибка: не указан URL или магнет-ссылка."
  exit 1
fi

TORRENT_URL="$1"
DOWNLOAD_DIR="$HOME/Downloads"

# Создание каталога для загрузки, если он не существует
mkdir -p "$DOWNLOAD_DIR"

# Запуск aria2 для загрузки файлов
echo "Начало загрузки с использованием aria2..."
aria2c \
  --dir="$DOWNLOAD_DIR" \
  --enable-dht \
  --dht-file-path="$HOME/.cache/aria2/dht.dat" \
  --bt-save-metadata=true \
  --seed-time=0 \
  --summary-interval=0 \
  --max-concurrent-downloads=5 \
  --split=16 \
  --bt-max-open-files=100 \
  --bt-tracker-connect-timeout=60 \
  --bt-tracker-timeout=60 \
  --bt-enable-lpd=true \
  --follow-torrent=mem \
  --check-certificate=false \
  --allow-overwrite=true \
  "$TORRENT_URL"

if [ $? -ne 0 ]; then
  echo "Ошибка загрузки с использованием aria2."
  exit 1
fi

echo "Загрузка завершена. Запуск обработки файлов..."

# Передача загруженных файлов в file_processing.sh
for FILE in "$DOWNLOAD_DIR"/*; do
  if [ -f "$FILE" ]; then
    echo "Обработка файла: $FILE"
    ./file_processing.sh "$FILE"
  fi
done

echo "Обработка завершена."
