#!/usr/bin/env bash

source $(dirname "$0")/../consul_init.sh
source $(dirname "$0")/../docker_init.sh
source $(dirname "$0")/../shared.sh


if [ "$#" -lt 1 ]; then
  error "Usage: config_dtr.sh <UCP_URL>"
  exit 1
fi

if [ ! -f $(dirname "$0")/ca.pem ]; then
    warn "ca.pem not found.  If you meant to apply custom certs, please copy the pem files into this script's working directory"
fi

if [ ! -f $(dirname "$0")/cert.pem ]; then
    warn "cert.pem not found.  If you meant to apply custom certs, please copy the pem files into this script's working directory"
fi

if [ ! -f $(dirname "$0")/key.pem ]; then
    warn "key.pem not found.  If you meant to apply custom certs, please copy the pem files into this script's working directory"
fi

API_BASE="http://127.0.0.1:8500/v1"
DTR_URL=https://localhost
UCP_URL=$1

NETWORK_INTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")

configure_dtr
