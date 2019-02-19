function timestamp {
  echo $(date "+%F %T")
}

function debug {
  echo "$(timestamp) DEBUG:  $HOSTNAME $1"
}

function info {
  echo "$(timestamp) INFO:  $HOSTNAME $1"
}

function error {
  echo "$(timestamp) ERROR: $HOSTNAME $1"
}

function my_ip {
  ADV_IP=$(/sbin/ip -f inet addr show dev $1 | grep -Po 'inet \K[\d.]+')
  info "My name is $HOSTNAME"
  info "My default network is $1"
  info "My IP address is $ADV_IP"
}
