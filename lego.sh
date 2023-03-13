#!/bin/bash

# Exit the script if a pipeline fails (-e), prevent accidental filename
# expansion (-f), and consider undefined variables as errors (-u).
set -e -f -u

# Env configuration
#
# DOMAIN_NAME       Main domain name we're obtaining a wildcard certificate for.
# DNS_PROVIDER      DNS provider lego uses to prove that you're in control of
# 					the domain. The current version supports the following hosts:
# 					"cloudflare", "digitalocean", "dreamhost", "duckdns" and "godaddy".
# EMAIL				Your email address.
#
# CloudFlare
# ---
# If you're using CloudFlare, you must specify the API token:
# https://developers.cloudflare.com/api/tokens/create
#
# CLOUDFLARE_DNS_API_TOKEN		Your API token.
#
#
# DigitalOcean
# ---
# If you're using DigitalOcean, you must specify the API token:
# https://cloud.digitalocean.com/account/api/tokens
#
# DO_AUTH_TOKEN		Your API token.
#
#
# DreamHost
# ---
# If you're using DreamHost you must specify the API key:
# https://panel.dreamhost.com/?tree=billing.api
#
# DREAMHOST_API_KEY     Your API key
#
#
# Duck DNS
# ---
# If you're using DuckDNS you must specify the API token
#
# DUCKDNS_TOKEN         Your API token
#
#
# GoDaddy
# ---
# If you're using GoDaddy, you must specify the API secret and key. The API
# credentials can be created here: https://developer.godaddy.com/keys
#
# GODADDY_API_KEY				API key.
# GODADDY_API_SECRET			API secret.

# Function error_exit is an echo wrapper that writes to stderr and stops the
# script execution with code 1.
error_exit() {
    echo "$1" 1>&2

    exit 1
}

# Function log is an echo wrapper that writes to stderr if the caller
# requested verbosity level greater than 0.  Otherwise, it does nothing.
log() {
    if [ "$verbose" -gt '0' ]; then
        echo "$1" 1>&2
    fi
}

check_env() {
    if [ -z "${DOMAIN_NAME+x}" ]; then
        error_exit "DOMAIN_NAME must be specified"
    fi

    if [ -z "${DNS_PROVIDER+x}" ]; then
        error_exit "DNS_PROVIDER must be specified"
    fi

    if [ -z "${EMAIL+x}" ]; then
        error_exit "EMAIL must be specified"
    fi

    if [ "${DNS_PROVIDER}" != 'godaddy' ] && [ "${DNS_PROVIDER}" != 'cloudflare' ] && [ "${DNS_PROVIDER}" != 'digitalocean' ] && [ "${DNS_PROVIDER}" != "dreamhost" ] && [ "${DNS_PROVIDER}" != 'duckdns' ]; then
        error_exit "DNS provider ${DNS_PROVIDER} is not supported"
    fi

    if [ "${DNS_PROVIDER}" = 'cloudflare' ]; then
        if [ -z "${CLOUDFLARE_DNS_API_TOKEN+x}" ]; then
            error_exit "CLOUDFLARE_DNS_API_TOKEN must be specified"
        fi
    fi

    if [ "${DNS_PROVIDER}" = 'godaddy' ]; then
        if [ -z "${GODADDY_API_KEY+x}" ]; then
            error_exit "GODADDY_API_KEY must be specified"
        fi

        if [ -z "${GODADDY_API_SECRET+x}" ]; then
            error_exit "GODADDY_API_SECRET must be specified"
        fi
    fi

    if [ "${DNS_PROVIDER}" = 'digitalocean' ]; then
        if [ -z "${DO_AUTH_TOKEN+x}" ]; then
            error_exit "DO_AUTH_TOKEN must be specified"
        fi
    fi

    if [ "${DNS_PROVIDER}" = 'dreamhost' ]; then
        if [ -z "${DREAMHOST_API_KEY+x}" ]; then
            error_exit "DREAMHOST_API_KEY must be specified"
        fi
    fi	

    if [ "${DNS_PROVIDER}" = 'duckdns' ]; then
        if [ -z "${DUCKDNS_TOKEN+x}" ]; then
            error_exit "DUCKDNS_TOKEN must be specified"
        fi
    fi	

}

# Function set_os sets the os if needed and validates the value.
set_os() {
    # Set if needed.
    if [ "$os" = '' ]; then
        os="$(uname -s)"
        case "$os" in

        'Darwin')
            os='darwin'
            ;;
        'FreeBSD')
            os='freebsd'
            ;;
        'Linux')
            os='linux'
            ;;
        'OpenBSD')
            os='openbsd'
            ;;
        esac
    fi

    # Validate.
    case "$os" in

    'darwin' | 'freebsd' | 'linux' | 'openbsd')
        # All right, go on.
        ;;
    *)
        error_exit "unsupported operating system: '$os'"
        ;;
    esac

    # Log.
    log "operating system: $os"
}

# Function set_cpu sets the cpu if needed and validates the value.
set_cpu() {
    # Set if needed.
    if [ "$cpu" = '' ]; then
        cpu="$(uname -m)"
        case "$cpu" in

        'x86_64' | 'x86-64' | 'x64' | 'amd64')
            cpu='amd64'
            ;;
        'i386' | 'i486' | 'i686' | 'i786' | 'x86')
            cpu='386'
            ;;
        'armv5l')
            cpu='armv5'
            ;;
        'armv6l')
            cpu='armv6'
            ;;
        'armv7l' | 'armv8l')
            cpu='armv7'
            ;;
        'aarch64' | 'arm64')
            cpu='arm64'
            ;;
        'mips' | 'mips64')
            if is_little_endian; then
                cpu="${cpu}le"
            fi
            cpu="${cpu}_softfloat"
            ;;
        esac
    fi

    # Validate.
    case "$cpu" in

    'amd64' | '386' | 'armv5' | 'armv6' | 'armv7' | 'arm64')
        # All right, go on.
        ;;
    'mips64le_softfloat' | 'mips64_softfloat' | 'mipsle_softfloat' | 'mips_softfloat')
        # That's right too.
        ;;
    *)
        error_exit "unsupported cpu type: $cpu"
        ;;
    esac

    # Log.
    log "cpu type: $cpu"
}

download_lego() {
    legoDist="lego.tar.gz"
    etagFile=".lego.etag"
    arch="_${os}_${cpu}.tar"
    releaseURL=$(curl -s "https://api.github.com/repos/go-acme/lego/releases/latest" | grep "browser_download_url" | grep "${arch}" | grep -o "https://[^\"]*")
    
    # If the lego executable doesn't exist then wipe our etags so that it gets re-downloaded
    if [ ! -f lego ]; then
        rm -f ${etagFile} 
    fi

    echo "Downloading the latest lego release from ${releaseURL}"
    curl -L --etag-save ${etagFile} --etag-compare ${etagFile} "${releaseURL}" --output ${legoDist}

    if [ -f ${legoDist} ]; then
        echo "Extracting the latest lego version"
        tar xvfz ${legoDist}
        rm ${legoDist}
    fi
}

run_lego_cloudflare() {
    if [ "${SERVER:-}" != "" ] &&
        [ "${EAB_KID:-}" != "" ] &&
        [ "${EAB_HMAC:-}" != "" ]; then
        CLOUDFLARE_DNS_API_TOKEN="${CLOUDFLARE_DNS_API_TOKEN}" \
            ./lego \
            --accept-tos \
            --server "${SERVER:-}" \
            --eab --kid "${EAB_KID:-}" --hmac "${EAB_HMAC:-}" \
            --dns cloudflare \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run
    else
        CLOUDFLARE_DNS_API_TOKEN="${CLOUDFLARE_DNS_API_TOKEN}" \
            ./lego \
            --accept-tos \
            --dns cloudflare \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run \
            --preferred-chain="ISRG Root X1"
    fi
}

run_lego_godaddy() {
    if [ "${SERVER:-}" != "" ] &&
        [ "${EAB_KID:-}" != "" ] &&
        [ "${EAB_HMAC:-}" != "" ]; then
        GODADDY_API_KEY="${GODADDY_API_KEY}" \
            GODADDY_API_SECRET="${GODADDY_API_SECRET}" \
            ./lego \
            --accept-tos \
            --server "${SERVER:-}" \
            --eab --kid "${EAB_KID:-}" --hmac "${EAB_HMAC:-}" \
            --dns godaddy \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run
    else
        GODADDY_API_KEY="${GODADDY_API_KEY}" \
            GODADDY_API_SECRET="${GODADDY_API_SECRET}" \
            ./lego \
            --accept-tos \
            --dns godaddy \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run \
            --preferred-chain="ISRG Root X1"
    fi
}

run_lego_digitalocean() {
    if [ "${SERVER:-}" != "" ] &&
        [ "${EAB_KID:-}" != "" ] &&
        [ "${EAB_HMAC:-}" != "" ]; then
        DO_AUTH_TOKEN="${DO_AUTH_TOKEN}" \
            ./lego \
            --accept-tos \
            --server "${SERVER:-}" \
            --eab --kid "${EAB_KID:-}" --hmac "${EAB_HMAC:-}" \
            --dns digitalocean \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run
    else
        DO_AUTH_TOKEN="${DO_AUTH_TOKEN}" \
            ./lego \
            --accept-tos \
            --dns digitalocean \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run \
            --preferred-chain="ISRG Root X1"
    fi
}

run_lego_dreamhost() {
    if [ "${SERVER:-}" != "" ] &&
        [ "${EAB_KID:-}" != "" ] &&
        [ "${EAB_HMAC:-}" != "" ]; then
        DREAMHOST_API_KEY="${DREAMHOST_API_KEY}" \
            ./lego \
            --accept-tos \
            --server "${SERVER:-}" \
            --eab --kid "${EAB_KID:-}" --hmac "${EAB_HMAC:-}" \
            --dns dreamhost \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run
    else
        DREAMHOST_API_KEY="${DREAMHOST_API_KEY}" \
            ./lego \
            --accept-tos \
            --dns dreamhost \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run \
            --preferred-chain="ISRG Root X1"
    fi
}


run_lego_duckdns() {
    if [ "${SERVER:-}" != "" ] &&
        [ "${EAB_KID:-}" != "" ] &&
        [ "${EAB_HMAC:-}" != "" ]; then
        DUCKDNS_TOKEN="${DUCKDNS_TOKEN}" \
            ./lego \
            --accept-tos \
            --server "${SERVER:-}" \
            --eab --kid "${EAB_KID:-}" --hmac "${EAB_HMAC:-}" \
            --dns duckdns \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run
    else
        DUCKDNS_TOKEN="${DUCKDNS_TOKEN}" \
            ./lego \
            --accept-tos \
            --dns duckdns \
            --domains "${wildcardDomainName}" \
            --domains "${domainName}" \
            --email "${email}" \
            --cert.timeout 600 \
            run \
            --preferred-chain="ISRG Root X1"
    fi
}

run_lego() {
    domainName="${DOMAIN_NAME}"
    wildcardDomainName="*.${DOMAIN_NAME}"
    email="${EMAIL}"

    case ${DNS_PROVIDER} in

    godaddy)
        run_lego_godaddy
        ;;

    cloudflare)
        run_lego_cloudflare
        ;;

    digitalocean)
    	run_lego_digitalocean
    	;;

    dreamhost)
        run_lego_dreamhost
        ;;

    duckdns)
    	run_lego_duckdns
    	;;

    *)
        error_exit "Unsupported DNS provider ${DNS_PROVIDER}"
        ;;
    esac
}

get_abs_filename() {
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

copy_certificate() {
    certFileName="${DOMAIN_NAME}"
    cp -f "./.lego/certificates/_.${certFileName}.key" "./${certFileName}.key"
    cp -f "./.lego/certificates/_.${certFileName}.crt" "./${certFileName}.crt"

    log "Your certificate and key are available at:"
    log "$(get_abs_filename ${certFileName}.crt)"
    log "$(get_abs_filename ${certFileName}.key)"
}

# Entrypoint

# Set default values of configuration variables.
verbose='1'
cpu=''
os=''
domainName=''
wildcardDomainName=''
email=''

check_env

set_os

set_cpu

download_lego

run_lego

copy_certificate
