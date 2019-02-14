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
