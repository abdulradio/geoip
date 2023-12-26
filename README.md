# GeoIP RU

geoip contains databases of IP addresses of Russia and Belarus(MaxMind), cloudflare, cloudfront, facebook, fastly, google, netflix, telegram, twitter.

## Example xray rules geoip.dat

```json
"routing":
{
    "domainStrategy": "IPIfNonMatch",
    "domainMatcher": "hybrid",
    "rules": [
      {
        "ip": ["geoip:telegram"],
        "outboundTag": "proxy",
         "type": "field"
      },
      {
        "ip": [ "geoip:private", "geoip:ru"],
        "outboundTag": "direct",
         "type": "field"
      },
      {
        "type": "field",
        "network": "udp",
        "ip": ["geoip:google"],
        "outboundTag": "direct"
      }
    ]
}
