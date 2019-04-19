function timestamp {
  echo $(date "+%F %T")
}

function debug {
  if [ "${debug_output}" -eq 1 ] || [ "${verbose_output}" -eq 1 ]; then
    echo "$(timestamp) DEBUG:   $HOSTNAME $1"
  fi
}

function verbose {
  if [ "${verbose_output}" -eq 1 ]; then
    echo "$(timestamp) VERBOSE:  $HOSTNAME $1"
  fi
}

function info {
  echo "$(timestamp) INFO:    $HOSTNAME $1"
}

function error {
  echo "$(timestamp) ERROR:   $HOSTNAME $1"
}

function my_ip {
  ADV_IP=$(/sbin/ip -f inet addr show dev $1 | grep -Po 'inet \K[\d.]+')
  echo "-------------------------"
  info "$(date "+%F %T") My name is $HOSTNAME"
  info "$(date "+%F %T") My default network is $1"
  info "$(date "+%F %T") My IP address is $ADV_IP"
  echo "-------------------------"
}

function wait_for_api {
    URL=$1
    until $(curl -k --output /dev/null --silent --head --fail $URL); do
        info "Waiting for $URL to be reachable"
        sleep 30
    done
    info "$URL is available"
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

function mark_swarm_ready {
  SWARM_TYPE=$1
  info "Setting flag to indicate that the $SWARM_TYPE swarm is initialized."
  curl -sX PUT -d "$HOSTNAME" "$API_BASE/kv/$${SWARM_TYPE}_swarm_initialized?release=$SID&flags=2"
}
