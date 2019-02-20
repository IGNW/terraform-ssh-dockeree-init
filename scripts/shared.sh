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
  echo "-------------------------"
  info "$(date "+%F %T") My name is $HOSTNAME"
  info "$(date "+%F %T") My default network is $1"
  info "$(date "+%F %T") My IP address is $ADV_IP"
  echo "-------------------------"
}
