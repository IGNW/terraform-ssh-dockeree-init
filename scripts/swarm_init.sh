#!/usr/bin/env bash
# This script initializes Consul, UCP, and DTR clusters.
# Further nodes are joined after the initial server/manager nodes are created.

set -e
API_BASE="http://127.0.0.1:8500/v1"

source $(dirname "$0")/consul_init.sh
source $(dirname "$0")/docker_init.sh
source $(dirname "$0")/shared.sh


NETWORK_INTERFACE=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
ADV_IP=$(/sbin/ip -f inet addr show dev $NETWORK_INTERFACE | grep -Po 'inet \K[\d.]+')
info "My IP address is $ADV_IP"

if [[ $HOSTNAME =~ mgr ]]; then
    info "This is a manager node"

      consul_server_init
      SID=$(curl -sX PUT $API_BASE/session/create | jq -r '.ID')
      # Check a key to find out if the UCP swarm is already initialized
      FLAGS=$(curl -s $API_BASE/kv/ucp_swarm_initialized | jq -r '.[0].Flags')
      if [[ -z $FLAGS ]]; then
        info "UCP swarm is uninitialized. Trying to get the lock."

        R=$(curl -sX PUT "$API_BASE/kv/ucp_swarm_initialized?acquire=$SID&flags=1")
        while [[ -z $R ]]; do
            info "No response to attempt to get lock. Consul not ready yet? Sleeping..."
            sleep 10
            R=$(curl -sX PUT "$API_BASE/kv/ucp_swarm_initialized?acquire=$SID&flags=1")
        done

        if [[ $R == "true" ]]; then
            info "Got the lock. Initializing the UCP swarm."
            create_ucp_swarm
        else
            info "Someone else got the lock first? R:($R)"
            swarm_wait_until_ready ucp ucp_swarm_initialized
            ucp_join_manager
        fi

      elif [[ "$FLAGS" == "1" ]]; then
          info "Found that swarm initialization is in progress"
          swarm_wait_until_ready ucp ucp_swarm_initialized
          ucp_join_manager

      elif [[ "$FLAGS" == "2" ]]; then
          info "Found that the swarm is already initialized"
          ucp_join_manager
  fi
  curl -sX PUT $API_BASE/session/destroy/$SID

elif [[ $HOSTNAME =~ wrk ]]; then
    info "This is a worker node"
    exit 0
    consul_agent_init
    swarm_wait_until_ready ucp ucp_swarm_initialized
    ucp_join_worker

elif [[ $HOSTNAME =~ dtr ]]; then
    info "This is a DTR worker node"
    exit 0
    consul_agent_init
    swarm_wait_until_ready ucp ucp_swarm_initialized
    ucp_join_worker

    SID=$(curl -sX PUT $API_BASE/session/create | jq -r '.ID')
    FLAGS=$(curl -s $API_BASE/kv/dtr_swarm_initialized | jq -r '.[0].Flags')
    if [[ -z $FLAGS ]]; then
        info "DTR swarm is uninitialized. Trying to get the lock."

        R=$(curl -sX PUT "$API_BASE/kv/dtr_swarm_initialized?acquire=$SID&flags=1")
        while [[ -z $R ]]; do
            info "No response to attempt to get lock. Consul not ready yet? Sleeping..."
            sleep 10
            R=$(curl -sX PUT "$API_BASE/kv/dtr_swarm_initialized?acquire=$SID&flags=1")
        done

        if [[ $R == "true" ]]; then
            info "Got the lock. Initializing the DTR swarm."
            dtr_install

        else
            info "Someone else got the lock first? R:($R)"
            swarm_wait_until_ready dtr dtr_swarm_initialized
            dtr_join
        fi

    elif [[ "$FLAGS" == "1" ]]; then
        info "Found that swarm initialization is in progress"
        swarm_wait_until_ready dtr dtr_swarm_initialized
        dtr_join

    elif [[ "$FLAGS" == "2" ]]; then
        info "Found that the swarm is already initialized"
        dtr_join
    fi
    curl -sX PUT $API_BASE/session/destroy/$SID
fi
info "CONFIGURATION COMPLETE"
