#!/usr/bin/env bash

input="./asn.csv"
mkdir -p ./tmp ./data

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

url_ru="https://stat.ripe.net/data/country-resource-list/data.json?resource=RU"
url_by="https://stat.ripe.net/data/country-resource-list/data.json?resource=BY"

echo "Generating RU CIDR list..."
curl -sL url_ru -o ripe/ip_RU.txt \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
    jq --raw-output '.data.resources.ipv4[]' ripe/ip_RU.txt | sort -u >>ip_RU.lst

echo "Generating BY CIDR list..."
curl -sL url_by -o ripe/ip_BY.txt \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
    jq --raw-output '.data.resources.ipv4[]' ripe/ip_BY.txt | sort -u >>ip_BY.lst