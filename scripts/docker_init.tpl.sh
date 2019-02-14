source $(dirname "$0")/shared.sh

function wait_for_ucp_manager {
    until $(curl -k --output /dev/null --silent --head --fail https://ucpmgr.service.consul); do
        info "Waiting for existing UCP manager to be reachable via HTTPS"
        sleep 15
    done
    info "Existing UCP manager is available"
}

function create_ucp_swarm {
    info "Creating UCP swarm"
    docker container run --rm -it --name ucp \
        -v /var/run/docker.sock:/var/run/docker.sock \
        docker/ucp:${ucp_version} install \
        --host-address ens160 \
        --admin-username ${ucp_admin_username} \
        --admin-password ${ucp_admin_password} \

    info "Storing manager/worker join tokens for UCP"
    MANAGER_TOKEN=$(docker swarm join-token -q manager)
    WORKER_TOKEN=$(docker swarm join-token -q worker)
    curl -sX PUT -d "$MANAGER_TOKEN" $API_BASE/kv/ucp/manager_token
    curl -sX PUT -d "$WORKER_TOKEN" $API_BASE/kv/ucp/worker_token

    info "Setting flag to indicate that the UCP swarm is initialized."
    curl -sX PUT -d "$HOSTNAME.node.consul" "$API_BASE/kv/ucp_swarm_initialized?release=$SID&flags=2"
    info "Registering this node as a UCP manager"
    curl -sX PUT -d '{"Name": "ucpmgr", "Port": 2377}' $API_BASE/agent/service/register
}
function ucp_join_manager {
    wait_for_ucp_manager
    info "UCP manager joining swarm"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/manager_token | jq -r '.[0].Value' | base64 -d)
    docker swarm join --token $JOIN_TOKEN ucpmgr.service.consul:2377
    info "Registering this node as a UCP manager"
    curl -sX PUT -d '{"Name": "ucpmgr", "Port": 2377}' $API_BASE/agent/service/register
}

function ucp_join_worker {
    wait_for_ucp_manager
    info "UCP worker joining swarm"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/worker_token | jq -r '.[0].Value' | base64 -d)
    docker swarm join --token $JOIN_TOKEN ucpmgr.service.consul:2377
}

function swarm_wait_until_ready {
    SWARM_TYPE=$1
    KEY=$2
    info "Started polling for $SWARM_TYPE readiness"
    FLAGS=$(curl -s $API_BASE/kv/$KEY | jq -r '.[0].Flags')
    info "$KEY FLAGS=$FLAGS"
    while [[ "$FLAGS" != "2" ]]; do
        info "Waiting for $SWARM_TYPE swarm to be ready for join"
        sleep 15
        FLAGS=$(curl -s $API_BASE/kv/$KEY | jq -r '.[0].Flags')
        info "$KEY FLAGS=$FLAGS"
    done
    info "$SWARM_TYPE swarm is ready"
}

function dtr_install {
    wait_for_ucp_manager

    sleep 15
    DTR_STATUS=1
    DTR_ATTEMPTS=0
    until [ "$DTR_STATUS" -eq 0 ]; do
      info "Attempting to start DTR"
      set +e
      docker run -it --rm  --name dtr docker/dtr install \
        --ucp-node $HOSTNAME \
        --ucp-username '${ucp_admin_username}' \
        --ucp-password '${ucp_admin_password}' \
        --ucp-insecure-tls \
        --ucp-url https://ucpmgr.service.consul \
        --dtr-external-url $ADV_IP
      DTR_STATUS=$?
      set +x
      debug "DTR STATUS $DTR_STATUS"
      if [ "$DTR_STATUS" -ne 0 ]; then
        DTR_ATTEMPTS=$((DTR_ATTEMPTS + 1))
        if [ $DTR_ATTEMPTS -gt 5 ]; then
          error "DTR failed too many times.  Exiting."
          exit 1
        else
          error "DTR failed to start.  Trying again."
          sleep 15
        fi
      fi
    done
    set -e
    debug "Putting replica ID into KV"
    curl -sX PUT -d "$REPLICA_ID" $API_BASE/kv/dtr/replica_id
    debug "Marking swarm initialization as complete in KV"
    curl -sX PUT -d "$HOSTNAME.node.consul" "$API_BASE/kv/dtr_swarm_initialized?release=$SID&flags=2"
    info "Finished initializing the DTR swarm"

    info "Applying Minio config"
    /tmp/config_dtr_minio.sh 2>&1
    debug "Done applying minio config"
}

function dtr_join {
    wait_for_ucp_manager
    info "Starting DTR join"
    REPLICA_ID=$(curl -s $API_BASE/kv/dtr/replica_id | jq -r '.[0].Value' | base64 -d)
    info "Retreived replace ID: $REPLICA_ID"

    # Ensure that only one DTR node can join at time to avoid contention.
    until [[ $(curl -sX PUT $API_BASE/kv/dtr/join_lock?acquire=$SID) == "true" ]]; do
        info "Waiting to acquire DTR join lock"
        sleep 15
    done
    info "Acquired DTR join lock"

    # Add a hosts entry so that this works before the load balancer is up
    MGR_IP=$(dig +short ucpmgr.service.consul | head -1 | tr -d " \n")

    docker run -it --rm docker/dtr join \
        --ucp-node $HOSTNAME \
        --ucp-username '${ucp_admin_username}' \
        --ucp-password '${ucp_admin_password}' \
        --existing-replica-id $REPLICA_ID \
        --ucp-insecure-tls \
        --ucp-url https://ucpmgr.service.consul

    info "Releasing DTR join lock."
    curl -sX PUT $API_BASE/kv/dtr/join_lock?release=$SID
}
