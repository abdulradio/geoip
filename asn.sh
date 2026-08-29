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
    rm -f "${file}" && touch "${file}"

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
    curl -sL --retry 3 "$url" -o "$json_file"

    # Извлекаем список IPv4
    jq -r '.data.resources.ipv4[]? // empty' "$json_file" | while read -r ip; do
        if [[ "$ip" == *-* ]]; then
            # Надежная конвертация диапазона IP (start-end) в CIDR через ipcalc
            ipcalc "$ip" | grep -v 'Deaggregating' | awk '{print $1}' >> "${output_file}.tmp"
        else
            echo "$ip" >> "${output_file}.tmp"
        fi
    done
}

output_ripe="ripe/ip_RU.lst"
rm -f "$output_ripe" "${output_ripe}.tmp"

# Собираем RU и BY
get_save_cidr "RU" "$output_ripe"
get_save_cidr "BY" "$output_ripe"

# Сортируем и убираем дубликаты
if [ -f "${output_ripe}.tmp" ]; then
    sort -u "${output_ripe}.tmp" > "$output_ripe"
    rm -f "${output_ripe}.tmp"
fi

echo "Done! Final list saved to $output_ripe"
