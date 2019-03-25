source $(dirname "$0")/shared.sh

function wait_for_ucp_manager {
    debug "Looking up UCP manager address"
    # Query the KV store for the IP address of one node registered as a manager
    set -x
    MANAGER_IP="$(curl -s $API_BASE/kv/ucp/nodes?raw=true | jq -r '.ips[0]')"
    set +x
    debug "Found a UCP manager at $MANAGER_IP"

    until $(curl -k --output /dev/null --silent --head --fail https://$MANAGER_IP); do
        info "Waiting for the UCP manager to be reachable via HTTPS"
        sleep 15
    done
    info "UCP manager is available"
}

function create_ucp_swarm {
    info "Creating UCP swarm"
    set +e
    docker_out="$(docker container run -d --name ucp \
        -v /var/run/docker.sock:/var/run/docker.sock \
        docker/ucp:${ucp_version} install \
        --host-address $NETWORK_INTERFACE \
        --admin-username ${ucp_admin_username} \
        --admin-password ${ucp_admin_password} \
        --san '${ucp_url}' \
        --license '${dockeree_license}' 2>&1)"
    UCP_STATUS=$?
    set -e
    debug "UCP status: $UCP_STATUS"
    debug "$docker_out"
    if [ $UCP_STATUS -ne 0 ]; then
      exit 1
    fi

    info "Registering this node as a UCP manager"
    curl -sX PUT -d "{\"ips\": [\"$ADV_IP\"]}" $API_BASE/kv/ucp/nodes
    debug "Ok, I'm done registering"


    wait_for_ucp_manager
    info "Storing manager/worker join tokens for UCP"
    MANAGER_TOKEN=$(docker swarm join-token -q manager 2>&1)
    WORKER_TOKEN=$(docker swarm join-token -q worker 2>&1)
    debug "MANAGER TOKEN: $MANAGER_TOKEN"
    debug "WORKER TOKEN:  $WORKER_TOKEN"
    curl -sX PUT -d "$MANAGER_TOKEN" $API_BASE/kv/ucp/manager_token
    curl -sX PUT -d "$WORKER_TOKEN" $API_BASE/kv/ucp/worker_token

    info "Setting flag to indicate that the UCP swarm is initialized."
    curl -sX PUT -d "$HOSTNAME.node.consul" "$API_BASE/kv/ucp_swarm_initialized?release=$SID&flags=2"

}

function ucp_join_manager {
    wait_for_ucp_manager
    info "UCP manager joining swarm"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/manager_token | jq -r '.[0].Value' | base64 -d)
    debug "JOIN_TOKEN: $JOIN_TOKEN"
    set +e
    JOIN_OUTPUT=$(docker swarm join --token $JOIN_TOKEN --advertise-addr $ADV_IP $MANAGER_IP:2377 2>&1)
    JOIN_RESULT="$?"
    set -e
    debug "Join result: $JOIN_RESULT: $JOIN_OUTPUT"
    info "Registering this node as a UCP manager"
    curl -sX PUT -d '{"Name": "ucpmgr", "Port": 2377}' $API_BASE/agent/service/register
}

function ucp_join_worker {
    wait_for_ucp_manager
    info "UCP worker joining swarm"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/worker_token | jq -r '.[0].Value' | base64 -d)
    debug "JOIN_TOKEN: $JOIN_TOKEN"
    debug "MANAGER_IP: $MANAGER_IP"
    set +e
    set -x
    JOIN_OUTPUT="$(docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377 2>&1)"
    JOIN_RESULT="$?"
    set +x
    set -e
    debug "Join result: $JOIN_RESULT: $JOIN_OUTPUT"
}

function swarm_wait_until_ready {
    SWARM_TYPE=$1
    KEY=$2
    info "Started polling for $SWARM_TYPE readiness"
    FLAGS=$(curl -s $API_BASE/kv/$KEY | jq -r '.[0].Flags')
    info "$KEY FLAGS=$FLAGS"
    while [[ "$FLAGS" != "2" ]]; do
        info "Waiting for $SWARM_TYPE swarm to be ready for join"
        sleep 30
        FLAGS=$(curl -s $API_BASE/kv/$KEY | jq -r '.[0].Flags')
        info "$KEY FLAGS=$FLAGS"
    done
    info "$SWARM_TYPE swarm is ready"
}

function dtr_install {
    DTR_STATUS=1
    DTR_ATTEMPTS=0
    REPLICA_ID="000000000000"

    until [ "$DTR_STATUS" -eq 0 ]; do
      info "Attempting to start DTR"
      DTR_OUTPUT="$(start_dtr)"
      DTR_STATUS=$?
      debug "$DTR_STATUS : $DTR_OUTPUT"
      if [ "$DTR_STATUS" -ne 0 ]; then
        DTR_ATTEMPTS=$((DTR_ATTEMPTS + 1))
        if [ $DTR_ATTEMPTS -gt 10 ]; then
          error "DTR failed too many times.  Exiting."
          exit 1
        else
          error "DTR failed to start.  Failed $DTR_ATTEMPTS time(s).  Trying again."
          sleep 30
        fi
      fi
    done
    set -e
    debug "Putting replica ID into KV"
    curl -sX PUT -d "$REPLICA_ID" $API_BASE/kv/dtr/replica_id
    debug "Marking swarm initialization as complete in KV"
    curl -sX PUT -d "$HOSTNAME.node.consul" "$API_BASE/kv/dtr_swarm_initialized?release=$SID&flags=2"
    info "Finished initializing the DTR swarm"
}

function start_dtr {
  set +e
  docker run -d --name dtr --restart on-failure docker/dtr:${dtr_version} install \
      --ucp-node $HOSTNAME \
      --ucp-username '${ucp_admin_username}' \
      --ucp-password '${ucp_admin_password}' \
      --ucp-insecure-tls \
      --ucp-url '${ucp_url}' \
      --replica-id  $REPLICA_ID
  set -e
}

function dtr_join {
    wait_for_ucp_manager
    info "Starting DTR join"
    REPLICA_ID=$(curl -s $API_BASE/kv/dtr/replica_id | jq -r '.[0].Value' | base64 -d)
    info "Retrieved replica ID: $REPLICA_ID"
    debug "SID=$SID"

    aquire_join_lock

    DTR_JOIN_STATUS=1
    DTR_JOIN_ATTEMPTS=0
    until [ "$DTR_JOIN_STATUS" -eq 0 ]; do
      info "Attempting to join DTR"
      JOIN_OUTPUT=$(try_join_dtr)
      DTR_JOIN_STATUS=$?

      debug "$DTR_JOIN_STATUS: $JOIN_OUTPUT"
      if [ "$DTR_JOIN_STATUS" -ne 0 ]; then
        DTR_JOIN_ATTEMPTS=$((DTR_ATTEMPTS + 1))
        if [ $DTR_JOIN_ATTEMPTS -gt 10 ]; then
          error "DTR join failed too many times.  Exiting."
          release_join_lock "$SID"
          exit 1
        else
          error "DTR failed to join.  Failed $DTR_JOIN_ATTEMPTS time(s).  Trying again."
          sleep 30
        fi
      fi
    done
    info "DTR Join Complete"
    release_join_lock "$SID"
}

function try_join_dtr {
  set +e
  docker run -d --name dtr docker/dtr:${dtr_version} join \
    --ucp-node $HOSTNAME \
    --ucp-username '${ucp_admin_username}' \
    --ucp-password '${ucp_admin_password}' \
    --existing-replica-id 000000000000 \
    --ucp-insecure-tls \
    --ucp-url ${ucp_url} 2>&1
  JOIN_RESULT=$?
  set -e
  if [[ $JOIN_RESULT -ne 0 ]]; then
    return $JOIN_RESULT
  fi
  JOIN_RESULT=$(docker wait dtr)
  if [[ $JOIN_RESULT -ne 0 ]]; then
    docker logs dtr
    return $JOIN_RESULT
  fi
}

function acquire_join_lock {
  # Ensure that only one DTR node can join at time to avoid contention.
  until [[ $(curl -sX PUT $API_BASE/kv/dtr/join_lock?acquire=$1) == "true" ]]; do
    info "Waiting to acquire DTR join lock"
    sleep 15
  done
  info "Acquired DTR join lock"
}

function release_join_lock {
  info "Releasing DTR join lock."
  curl -sX PUT $API_BASE/kv/dtr/join_lock?release=$1
}
