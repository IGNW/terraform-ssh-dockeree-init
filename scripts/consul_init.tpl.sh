source $(dirname "$0")/shared.sh

function consul_prepare {
  debug "My name is $HOSTNAME"
  debug "My IP address is $ADV_IP"
  debug "There are ${node_count} nodes in my cluster"
  debug "The IP addresses of my cluster are: ${node_ips}"
  ip_list=($(echo ${node_ips} | sed -e "s/$ADV_IP//"))
  debug "List of cluster IPs who aren't me: $${ip_list[*]}"
}

function consul_server_init {
    consul_prepare
    info "Initializing Consul server"
    docker run -d --net=host --name consul \
        consul agent -server \
        -bind="0.0.0.0" \
        -advertise="$ADV_IP" \
        -data-dir='/tmp' \
        -encrypt='${consul_secret}' \
        -retry-join="$${ip_list[0]}" \
        -retry-join="$${ip_list[1]}" \
        -bootstrap-expect="${node_count}"

    wait_for_consul_leader
}

function get_leader {
    curl -s $API_BASE/status/leader | tr -d '"'
}

function wait_for_consul_leader {
    debug "Waiting for consul leader"
    LEADER=$(get_leader)
    while [[ -z $LEADER || $LEADER == "No known Consul servers" || $LEADER == "No cluster leader" ]]; do
        info "No Consul leader is available/elected yet. Sleeping for 15 seconds"
        sleep 15
        LEADER=$(get_leader)
    done
    info "Consul leader is present: $LEADER"
}

function consul_agent_init {
    consul_prepare
    info "Initializing Consul agent - connecting to ${consul_url}"
    set -x
    docker run -d --net=host --name consul \
        consul agent \
        -bind="0.0.0.0" \
        -advertise="$ADV_IP" \
        -data-dir='/tmp' \
        -encrypt='${consul_secret}' \
        -retry-join="${consul_url}"
    debug "Finished running consul agent container"
    docker ps
    docker logs consul
    set -x
    wait_for_consul_leader
}
