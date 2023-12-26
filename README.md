# GeoIP RU

geoip contains databases of IP addresses of Russia and Belarus - from MaxMind, cloudflare, cloudfront, facebook, fastly, google, netflix, telegram, twitter.

This project releases GeoIP files automatically every Thursday. It also provides a command line interface(CLI) for users to customize their own GeoIP files, included but not limited to V2Ray dat format file `geoip.dat` and MaxMind mmdb format file `Country.mmdb`.

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
