#!/bin/bash

# Проверка наличия 7z
if ! command -v 7z &> /dev/null; then
    echo "7z не установлен, устанавливаем..."
    sudo apt-get update
    sudo apt-get install -y p7zip-full p7zip-rar
fi

# Проверка наличия Python (для вычисления CRC-32)
if ! command -v python3 &> /dev/null; then
    echo "Python3 не установлен, устанавливаем..."
    sudo apt-get update
    sudo apt-get install -y python3
fi

# Получаем путь к скачанному файлу
downloaded_file=$(FILE)

if [ -z "$downloaded_file" ]; then
    echo "Не передан путь к скачанному файлу!"
    exit 1
fi

# Создаем временную директорию для проверки содержимого
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

echo "Проверяем файл $downloaded_file как архив..."
if ! 7z t "$downloaded_file" > /dev/null 2>&1; then
    echo "Файл не является поддерживаемым архивом или поврежден!"
    exit 1
fi

# Извлекаем список содержимого архива
echo "Получение списка содержимого архива..."
7z l "$downloaded_file" > "$temp_dir/archive_list.txt"
if [ $? -ne 0 ]; then
    echo "Ошибка чтения содержимого архива!"
    exit 1
fi

echo "Содержимое архива:"
cat "$temp_dir/archive_list.txt"

# Проверяем наличие файлов с расширениями .dll, .ini, .exe
echo "Проверка наличия файлов с интересующими расширениями..."
grep -E "\.(dll|ini|exe)$" "$temp_dir/archive_list.txt" > /dev/null
if [ $? -ne 0 ]; then
    echo "В архиве нет файлов с интересующими расширениями."
    exit 1
fi

# Распаковываем архив
echo "Распаковываем содержимое архива в $temp_dir..."
7z x "$downloaded_file" -o"$temp_dir"
if [ $? -ne 0 ]; then
    echo "Ошибка распаковки архива!"
    exit 1
fi

# Создаем директорию для фильтрованных файлов
filtered_files_dir="$temp_dir/filtered"
mkdir -p "$filtered_files_dir"

# Переносим только нужные файлы и вычисляем их CRC-32
echo "Обрабатываем файлы .dll, .ini, .exe и вычисляем их CRC-32..."
find "$temp_dir" -type f \( -iname "*.dll" -o -iname "*.ini" -o -iname "*.exe" \) | while IFS= read -r file; do
    # Копируем файл в фильтрованную директорию
    cp "$file" "$filtered_files_dir"

    # Вычисляем CRC-32
    crc32=$(python3 -c "
import zlib, sys
with open('$file', 'rb') as f:
    print(f'{zlib.crc32(f.read()) & 0xFFFFFFFF:08x}')
")
    echo "Файл: $file, CRC-32: $crc32"
done

# Создаем новый архив
output_archive="${downloaded_file%.*}_filtered.7z"
echo "Создаем новый архив $output_archive..."
7z a -mx=9 "$output_archive" "$filtered_files_dir"/*
if [ $? -ne 0 ]; then
    echo "Ошибка создания архива!"
    exit 1
fi

# Перемещаем архив в директорию для артефактов GitHub Actions
artifacts_dir="${GITHUB_WORKSPACE}/artifacts"
mkdir -p "$artifacts_dir"
mv "$output_archive" "$artifacts_dir"

echo "Архив успешно создан и перемещен: $artifacts_dir/$output_archive"
