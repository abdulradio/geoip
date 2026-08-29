#!/usr/bin/env bash

input="./asn.csv"
mkdir -p ./tmp ./data ./ripe

# 1. Сбор по ASN
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue

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
    jq --raw-output '.data.prefixes.v4.originating[]? // empty' ./tmp/${filename}-${asn}.txt | sort -u >>${file}
    jq --raw-output '.data.prefixes.v6.originating[]? // empty' ./tmp/${filename}-${asn}.txt | sort -u >>${file}
  done
done <${input}

# 2. Быстрое получение списков IP по странам через реестр NRO (All RIRs)
echo "==================================="
echo "Fetching full country stats from NRO Combined dataset..."
curl -sSL https://ftp.ripe.net/pub/stats/ripencc/nro-stats/latest/combined-stat -o ./tmp/combined-stat

# Сохраняем IPv4 и IPv6 для RU в ripe/ip_RU.lst (и дублируем в data/ru, если ваш Go-билдер берет оттуда)
echo "Generating RU IP list..."
> ripe/ip_RU.lst
grep -E "\|RU\|ipv4\|" ./tmp/combined-stat | awk -F'|' 'BEGIN{OFS="/"}{ if ($5>0) print $4, 32-log($5)/log(2) }' >> ripe/ip_RU.lst
grep -E "\|RU\|ipv6\|" ./tmp/combined-stat | awk -F'|' '{print $4"/"$5}' >> ripe/ip_RU.lst
cp ripe/ip_RU.lst data/ru 2>/dev/null || true

# Сохраняем IPv4 и IPv6 для BY в ripe/ip_BY.lst
echo "Generating BY IP list..."
> ripe/ip_BY.lst
grep -E "\|BY\|ipv4\|" ./tmp/combined-stat | awk -F'|' 'BEGIN{OFS="/"}{ if ($5>0) print $4, 32-log($5)/log(2) }' >> ripe/ip_BY.lst
grep -E "\|BY\|ipv6\|" ./tmp/combined-stat | awk -F'|' '{print $4"/"$5}' >> ripe/ip_BY.lst
cp ripe/ip_BY.lst data/by 2>/dev/null || true

echo "==================================="
echo "Списки IP-адресов для стран RU и BY успешно созданы!"
