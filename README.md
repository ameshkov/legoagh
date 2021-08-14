# legoagh

A simple script for automating using lego with [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome). 
It downloads the latest available release of lego, runs it and obtains 
a wildcard certificate for the specified domain.

Prepare:

```bash
mkdir /opt/lego
curl -s https://raw.githubusercontent.com/ameshkov/legoagh/master/lego.sh --output lego.sh
chmod +x lego.sh
```

If you're using CloudFlare, you need to [create an API](https://developers.cloudflare.com/api/tokens/create) token first.

Then run the script:

```bash
DOMAIN_NAME="example.org" \
    EMAIL="you@email" \
    DNS_PROVIDER="cloudflare" \
    CLOUDFLARE_DNS_API_TOKEN="yourapitoken" \
    ./lego.sh
```

If you're using GoDaddy, you need to [create the API credentials](https://developer.godaddy.com/keys).

Then run the script:

```bash
DOMAIN_NAME="example.org" \
    EMAIL="you@email" \
    DNS_PROVIDER="godaddy" \
    GODADDY_API_KEY="yourapikey" \
    GODADDY_API_SECRET="yourapisecret" \
    ./lego.sh
```