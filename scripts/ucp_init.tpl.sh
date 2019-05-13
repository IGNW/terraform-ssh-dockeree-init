function initialize_cluster {
   info "Initializing the Docker EE cluster"
   set -x
   SWARM_INIT_OUT=$(docker swarm init --advertise-addr $ADV_IP 2>&1)
   set +x
   debug $SWARM_INIT_OUT
   info "Apply initial UCP configuration"
   set -x
   CONFIG_CREATE_OUT=$(docker config create com.docker.ucp.config ucp_config.toml 2>&1)
   set +x
   debug $CONFIG_CREATE_OUT
}

function create_ucp_swarm {
    info "Creating UCP swarm"

    docker_out="$(docker container run -d --name ucp \
        -v /var/run/docker.sock:/var/run/docker.sock \
        docker/ucp:${ucp_version} install \
        --host-address $ADV_IP \
        --admin-username ${ucp_admin_username} \
        --admin-password ${ucp_admin_password} \
        --license '${dockeree_license}')"
    UCP_STATUS=$?
    if [ $UCP_STATUS -ne 0 ]; then
      error "$UCP_STATUS result from 'docker run docker/ucp install'"
    fi

    info "Removing UCP configuration"
    set -x
    CONFIG_RM_OUT=$(docker config rm com.docker.ucp.config 2>&1)
    set +x
    debug $CONFIG_RM_OUT

    info "Registering this node as the UCP leader ($ADV_IP)"
    curl -sX PUT -d "{\"ip\": \"$ADV_IP\"}" $API_BASE/kv/ucp_leader

    wait_for_api $UCP_URL
    info "Storing manager/worker join tokens for UCP"
    MANAGER_TOKEN=$(docker swarm join-token -q manager 2>&1)
    WORKER_TOKEN=$(docker swarm join-token -q worker 2>&1)
    debug "MANAGER TOKEN: $MANAGER_TOKEN"
    debug "WORKER TOKEN:  $WORKER_TOKEN"
    curl -sX PUT -d "$MANAGER_TOKEN" $API_BASE/kv/ucp/manager_token
    curl -sX PUT -d "$WORKER_TOKEN" $API_BASE/kv/ucp/worker_token
}



function ucp_join_manager {

    info "UCP manager joining swarm"
    UCP_LEADER="$(curl -s $API_BASE/kv/ucp_leader?raw=true | jq -r '.ip')"
    debug "UCP_LEADER: $UCP_LEADER"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/manager_token | jq -r '.[0].Value' | base64 -d)
    debug "JOIN_TOKEN: $JOIN_TOKEN"

    JOIN_OUTPUT=$(docker swarm join --token $JOIN_TOKEN --advertise-addr $ADV_IP $UCP_LEADER:2377 2>&1)
    JOIN_RESULT="$?"
    debug "Join result: $JOIN_RESULT: $JOIN_OUTPUT"
}

function ucp_join_worker {
    wait_for_api $UCP_URL
    info "UCP worker joining swarm"
    UCP_LEADER="$(curl -s $API_BASE/kv/ucp_leader?raw=true | jq -r '.ip')"
    debug "UCP_LEADER: $UCP_LEADER"
    JOIN_TOKEN=$(curl -s $API_BASE/kv/ucp/worker_token | jq -r '.[0].Value' | base64 -d)
    debug "JOIN_TOKEN: $JOIN_TOKEN"
    set -x
    JOIN_OUTPUT="$(docker swarm join --token $JOIN_TOKEN $UCP_LEADER:2377 2>&1)"
    JOIN_RESULT="$?"
    set +x
    debug "Join result: $JOIN_RESULT: $JOIN_OUTPUT"
}



function configure_ucp {
  info "Configuring the UCP settings"
  wait_for_api $UCP_URL
  configure_ucp_ssl
  info "Configuration complete"
}

function configure_ucp_ssl {
  debug "Configuring SSL Certificates"

  if [ "${use_custom_ssl}" -eq 1 ]; then
    info "Configuring custom SSL certificates for the UCP"
    # Read certs from files and replace actual newlines with \n
    CA=$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $(dirname "$0")/ca.pem)
    CERT=$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $(dirname "$0")/cert.pem)
    KEY=$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' $(dirname "$0")/key.pem)
    debug "I've read in those files (and replaced the newlines with \n)"
    verbose "CA: $CA"
    verbose "CERT: $CERT"
    verbose "KEY: $KEY"

    # Authenticate to the UCP API
    while [[ -z $AUTH_TOKEN || $AUTH_TOKEN == "null" ]]; do
      debug "I am going to sleep for 20 seconds"
      sleep 20s
      info ">> Attempting to authenticate"
      AUTH_TOKEN="$(curl -sk -d '{"username":"${ucp_admin_username}","password":"${ucp_admin_password}"}' $UCP_URL/auth/login | jq -r .auth_token 2>/dev/null)"
      debug "AUTH_TOKEN: $AUTH_TOKEN"
    done
    info ">> Authenticated"

    info ">> Applying SSL certs"
    HTTP_CODE=$(curl -sk --write-out '%%{http_code}' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -X POST "$UCP_URL/api/nodes/certs" \
    -d "{\"CA\":\"$CA\",\"Cert\":\"$CERT\",\"Key\":\"$KEY\"}")
    CURL_STATUS=$?

    debug "CURL_STATUS: $CURL_STATUS; HTTP_CODE: $HTTP_CODE"

  else
    info "Using self-signed SSL certificates"
  fi
}
