#!/usr/bin/env bash
set -e

input="./asn.csv"
mkdir -p ./tmp ./data ./ripe

# ----------------------------------------------------
# 1. Сбор IP по ASN (RIPE RIS Prefixes)
# ----------------------------------------------------
if [ -f "$input" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # Пропускаем пустые строки и комментарии
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    filename=$(echo "$line" | awk -F ',' '{print $1}')
    asns_str=$(echo "$line" | awk -F ',' '{print $2}')
    IFS='|' read -r -a asns <<< "$asns_str"
    file="data/${filename}"

    echo "==================================="
    echo "Generating ${filename} CIDR list..."
    rm -f "${file}" "${file}.tmp" && touch "${file}"

    for asn in "${asns[@]}"; do
      # Убираем пробелы, если есть
      asn=$(echo "$asn" | xargs)
      [ -z "$asn" ] && continue

      url="https://stat.ripe.net/data/ris-prefixes/data.json?list_prefixes=true&types=o&resource=${asn}"
      echo "Fetching ${asn}..."
      
      tmp_file="./tmp/${filename}-${asn}.txt"
      curl -sL --retry 3 "${url}" -o "$tmp_file" \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

      if [ -s "$tmp_file" ]; then
        jq -r '.data.prefixes.v4.originating[]? // empty' "$tmp_file" >> "${file}.tmp"
        jq -r '.data.prefixes.v6.originating[]? // empty' "$tmp_file" >> "${file}.tmp"
      fi
    done

    if [ -f "${file}.tmp" ]; then
      sort -u "${file}.tmp" > "${file}"
      rm -f "${file}.tmp"
    fi
  done < "${input}"
fi

# ----------------------------------------------------
# 2. Сбор IP по странам (RIPE Country Resource List)
# ----------------------------------------------------
get_save_cidr() {
    local country_code="$1"
    local output_file="$2"
    local url="https://stat.ripe.net/data/country-resource-list/data.json?resource=$country_code"

    echo "Fetching country resources for ${country_code}..."
    local json_file="./tmp/country-${country_code}.json"
    rm -f "${output_file}.tmp"
    curl -sL --retry 3 "$url" -o "$json_file"

    # Извлекаем список IPv4
    jq -r '.data.resources.ipv4[]? // empty' "$json_file" | while read -r ip; do
        if [[ "$ip" == *-* ]]; then
            # Заменяем дефис на пробел для правильного вызова ipcalc
            start_ip=$(echo "$ip" | cut -d'-' -f1)
            end_ip=$(echo "$ip" | cut -d'-' -f2)
            ipcalc "$start_ip" "$end_ip" | grep -v 'Deaggregating' | awk '{print $1}' >> "${output_file}.tmp"
        else
            echo "$ip" >> "${output_file}.tmp"
        fi
    done

    # Сортируем и сохраняем итоговый файл для страны
    if [ -f "${output_file}.tmp" ]; then
        sort -u "${output_file}.tmp" > "$output_file"
        rm -f "${output_file}.tmp"
    else
        touch "$output_file"
    fi
}

# Генерируем раздельные файлы, требуемые Go-сборщиком
get_save_cidr "RU" "ripe/ip_RU.lst"
get_save_cidr "BY" "ripe/ip_BY.lst"

echo "Done! Individual files saved to ripe/ip_RU.lst and ripe/ip_BY.lst"
