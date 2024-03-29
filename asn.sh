#!/usr/bin/env bash

input="./asn.csv"
mkdir -p ./tmp ./data ./ripe

while IFS= read -r line; do
  filename=$(echo ${line} | awk -F ',' '{print $1}')
  IFS='|' read -r -a asns <<<$(echo ${line} | awk -F ',' '{print $2}')
  file="data/${filename}"

  echo "==================================="
  echo "Generating ${filename} CIDR list..."
  rm -rf ${file} && touch ${file}
  for asn in ${asns[@]}; do
    url="https://stat.ripe.net/data/ris-prefixes/data.json?list_prefixes=true&types=o&resource=${asn}"
    echo "-----------------------"
    echo "Fetching ${asn}..."
    curl -sL ${url} -o ./tmp/${filename}-${asn}.txt \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
    jq --raw-output '.data.prefixes.v4.originating[]' ./tmp/${filename}-${asn}.txt | sort -u >>${file}
    jq --raw-output '.data.prefixes.v6.originating[]' ./tmp/${filename}-${asn}.txt | sort -u >>${file}
  done
done <${input}

# Функция для получения и сохранения IP-адресов в формате CIDR
get_save_cidr() {
    local country_code="$1"
    local output_file="$2"
    local url="https://stat.ripe.net/data/country-resource-list/data.json?resource=$country_code"

    # Получаем список IP-адресов IPv4 для указанной страны
    ipv4_addresses=$(curl -s "$url" | jq -r '.data.resources.ipv4[]')

    # Сохраняем список IP-адресов в формате CIDR в файл
    for ip in $ipv4_addresses; do
        if [[ "$ip" == *-* ]]; then
            ips=($(echo "$ip" | tr '-' ' '))
            start_ip="${ips[0]}"
            end_ip="${ips[1]}"
            cidr=$(convert_to_cidr "$start_ip" "$end_ip")
            echo "$cidr" >> "$output_file"
        else
            echo "$ip" >> "$output_file"
        fi
    done
}

# Функция для преобразования IP-адресов в формат CIDR
convert_to_cidr() {
    local start_ip="$1"
    local end_ip="$2"
    
    # Преобразование IP-адресов в целочисленное представление
    start=$(IFS=. read -r a b c d <<< "$start_ip"; printf "%d\n" "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))")
    end=$(IFS=. read -r a b c d <<< "$end_ip"; printf "%d\n" "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))")
    
    # Вычисление длины префикса CIDR
    prefix_len=0
    while [ $((start & 1)) -eq $((end & 1)) ]; do
        ((prefix_len++))
        start=$((start >> 1))
        end=$((end >> 1))
    done
    
    # Формирование CIDR
    network=$(IFS=. read -r a b c d <<< "$start_ip"; printf "%d.%d.%d.%d/%d\n" "$a" "$b" "$c" "$d" "$((32 - prefix_len))")
    echo "$network"
}

# Сохраняем список IP-адресов IPv4 для страны RU
get_save_cidr "RU" "ripe/ip_RU.lst"

# Сохраняем список IP-адресов IPv4 для страны BY
get_save_cidr "BY" "ripe/ip_RU.lst"

echo "Списки IP-адресов для стран RU и BY сохранены в соответствующих файлах"