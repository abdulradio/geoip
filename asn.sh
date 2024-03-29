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

url_ru="https://stat.ripe.net/data/country-resource-list/data.json?resource=RU"
url_by="https://stat.ripe.net/data/country-resource-list/data.json?resource=BY"

ripe_ip=$(curl -s "$url_ru" | jq -r '.data.resources.ipv4[]')

for record in $ripe_ip; do
  if [[ "$record" == *-* ]]; then
    ips=($(echo "$record" | tr '-' ' '))
    for ((ip=$(printf '%d' "$(echo "${ips[0]}" | tr . '\n' | awk '{s = s * 256 + $1} END {print s}')" ); ip <= $(printf '%d' "$(echo "${ips[1]}" | tr . '\n' | awk '{s = s * 256 + $1} END {print s}')" ); ip++ )); do
      printf -v ipaddr "%d.%d.%d.%d\n" "$((ip >> 24 & 255))" "$((ip >> 16 & 255))" "$((ip >> 8 & 255))" "$((ip & 255))"
      networks+=("$ipaddr")
    done
  else
    networks+=("$record")
  fi
done

aggregate_prefixes() {
  printf '%s\n' "${networks[@]}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | awk -F. 'BEGIN{OFS="."} {mask=32; while(and($1,1)==and($1,2^mask)) {mask--;$1=int($1/2)}; print $1,$2,$3,$4"/"(32-mask)}'
}

aggregate_prefixes | while read -r line; do
  number_of_ips=$((number_of_ips + $(awk -F'/' '{print 2^(32-$2)}' <<< "$line")))
  echo "$line"
done > ripe/ip_RU.lst

ripe_ip=$(curl -s "$url_by" | jq -r '.data.resources.ipv4[]')

for record in $ripe_ip; do
  if [[ "$record" == *-* ]]; then
    ips=($(echo "$record" | tr '-' ' '))
    for ((ip=$(printf '%d' "$(echo "${ips[0]}" | tr . '\n' | awk '{s = s * 256 + $1} END {print s}')" ); ip <= $(printf '%d' "$(echo "${ips[1]}" | tr . '\n' | awk '{s = s * 256 + $1} END {print s}')" ); ip++ )); do
      printf -v ipaddr "%d.%d.%d.%d\n" "$((ip >> 24 & 255))" "$((ip >> 16 & 255))" "$((ip >> 8 & 255))" "$((ip & 255))"
      networks+=("$ipaddr")
    done
  else
    networks+=("$record")
  fi
done

aggregate_prefixes() {
  printf '%s\n' "${networks[@]}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | awk -F. 'BEGIN{OFS="."} {mask=32; while(and($1,1)==and($1,2^mask)) {mask--;$1=int($1/2)}; print $1,$2,$3,$4"/"(32-mask)}'
}

aggregate_prefixes | while read -r line; do
  number_of_ips=$((number_of_ips + $(awk -F'/' '{print 2^(32-$2)}' <<< "$line")))
  echo "$line"
done > ripe/ip_BY.lst