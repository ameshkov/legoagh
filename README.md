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

By default, it uses [Let's Encrypt](https://letsencrypt.org/) to generate the certificate.

Alternatively, you can use a different provider. For instance, [ZeroSSL](https://zerossl.com/).

To do this, you need to sign up for a ZeroSSL account and obtain your EAB credentials.
Then just pass it to the script:

```bash
SERVER="https://acme.zerossl.com/v2/DV90" \
    EAB_KID="xxxx" \
    EAB_HMAC="xxxx" \
    ...
    ...
    ./lego.sh
```
