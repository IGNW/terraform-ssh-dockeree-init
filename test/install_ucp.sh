#!/usr/bin/env bash
API_BASE="http://127.0.0.1:8500/v1"

source $(dirname "$0")/../consul_init.sh
source $(dirname "$0")/../docker_init.sh
source $(dirname "$0")/../shared.sh


NETWORK_INTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
my_ip $NETWORK_INTERFACE
export UCP_URL="https://localhost"
CERTIFICATE_FLAG="--external-server-cert --preserve-certs"

create_ucp_swarm
