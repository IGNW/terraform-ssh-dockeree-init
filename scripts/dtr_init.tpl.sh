function dtr_install {
    wait_for_api $UCP_URL

    sleep 30
    DTR_INSTALL_RESULT=1
    DTR_INSTALL_ATTEMPTS=0
    REPLICA_ID="000000000000"

    until [ "$DTR_INSTALL_RESULT" -eq 0 ]; do
      info "Attempting to install the DTR"
      start_dtr
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
    debug "Putting replica ID into KV"
    curl -sX PUT -d "$REPLICA_ID" $API_BASE/kv/dtr/replica_id
    info "Finished initializing the DTR swarm"
}

function start_dtr {

  UCP_LEADER="$(curl -s $API_BASE/kv/ucp_leader?raw=true | jq -r '.ip')"
  debug "UCP_LEADER: $UCP_LEADER"

  OUTPUT=$(docker run --name dtr docker/dtr:${dtr_version} install \
      --ucp-node $HOSTNAME \
      --ucp-username '${ucp_admin_username}' \
      --ucp-password '${ucp_admin_password}' \
      --ucp-url "$UCP_URL" \
      --nfs-storage-url '${dtr_nfs_url}' \
      --replica-id  $REPLICA_ID \
      --ucp-insecure-tls 2>&1)

  DTR_INSTALL_RESULT=$?
  debug "DTR_INSTALL_RESULT (from container run result): $DTR_INSTALL_RESULT"
  debug "OUTPUT: $OUTPUT"
  if [[ $DTR_INSTALL_RESULT -eq 0 ]]; then
    DTR_INSTALL_RESULT=$(docker wait dtr)
    debug "DTR_INSTALL_RESULT (from container exit code): $DTR_INSTALL_RESULT"
    if [[ $DTR_INSTALL_RESULT -ne 0 ]]; then
      info "DTR install container exited with an error $DTR_INSTALL_RESULT"
      debug "Docker logs: $(docker logs dtr)"
    fi
  fi
  docker rename dtr "dtr-$(timestamp)"
}

function dtr_join {
    wait_for_api $UCP_URL
    info "Starting DTR join"
    REPLICA_ID=$(curl -s $API_BASE/kv/dtr/replica_id | jq -r '.[0].Value' | base64 -d)
    info "Retrieved replica ID: $REPLICA_ID"
    debug "SID=$SID"
    get_join_lock $SID

    DTR_JOIN_RESULT=1
    DTR_JOIN_ATTEMPTS=0
    until [ "$DTR_JOIN_RESULT" -eq 0 ]; do
      info "Attempting to join DTR"
      try_join_dtr

      debug "JOIN_RESULT: $DTR_JOIN_RESULT"
      if [ "$DTR_JOIN_RESULT" -ne 0 ]; then
        DTR_JOIN_ATTEMPTS=$((DTR_JOIN_ATTEMPTS + 1))
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
  debug "Running the docker run docker/dtr join command"
  UCP_LEADER="$(curl -s $API_BASE/kv/ucp_leader?raw=true | jq -r '.ip')"
  debug "UCP_LEADER: $UCP_LEADER"

  OUTPUT=$(docker run -d --name dtr docker/dtr:${dtr_version} join \
    --ucp-node $HOSTNAME \
    --ucp-username '${ucp_admin_username}' \
    --ucp-password '${ucp_admin_password}' \
    --existing-replica-id 000000000000 \
    --ucp-insecure-tls \
    --ucp-url "$UCP_URL" 2>&1)

  DTR_JOIN_RESULT=$?
  debug "JOIN_RESULT (from container run result): $DTR_JOIN_RESULT"
  debug "OUTPUT: $OUTPUT"
  if [[ $DTR_JOIN_RESULT -eq 0 ]]; then
    DTR_JOIN_RESULT=$(docker wait dtr)
    debug "JOIN_RESULT (from container exit code): $DTR_JOIN_RESULT"
    if [[ $DTR_JOIN_RESULT -ne 0 ]]; then
      info "DTR join container exited with an error $DTR_JOIN_RESULT"
      debug "Docker logs: $(docker logs dtr 2>&1)"
      docker rm dtr
    fi
  fi
}

function get_join_lock {
  # Ensure that only one DTR node can join at time to avoid contention.
  SID=$1
  debug "Attempting to get DTR join lock: $SID"
  until [[ $(curl -sX PUT $API_BASE/kv/dtr/join_lock?acquire=$SID) == "true" ]]; do
    info "Waiting to acquire DTR join lock"
    sleep 15
  done
  info "Acquired DTR join lock"
}

function release_join_lock {
  SID=$1
  info "Releasing DTR join lock: $SID"
  curl -sX PUT $API_BASE/kv/dtr/join_lock?release=$SID
}

function configure_dtr {
  info "Configuring the DTR settings"
  wait_for_api $UCP_URL
  wait_for_dtr $DTR_URL
  configure_dtr_ssl
  if [ -n "${dtr_s3_bucket}" ]; then
    configure_s3_dtr_storage
  fi
  info "Configuration complete"
}

function configure_dtr_ssl {
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
    verbose "KEY: $KEY":

    info ">> Applying SSL certs"
    HTTP_CODE=$(curl -sk --write-out '%%{http_code}' \
    -u "${ucp_admin_username}":"${ucp_admin_password}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST "$DTR_URL/api/v0/meta/settings" \
    -d "{\"dtrHost\":\"${dtr_fqdn}\",\"webTLSCA\":\"$CA\",\"webTLSCert\":\"$CERT\",\"webTLSKey\":\"$KEY\"}")
    CURL_STATUS=$?

    debug "CURL_STATUS: $CURL_STATUS; HTTP_CODE: $HTTP_CODE"

  else
    info "Using self-signed SSL certificates"
  fi
}

function configure_s3_dtr_storage {
  info "Configuring S3 storage for DTR"
  debug "S3 region: ${dtr_s3_region}"
  debug "S3 bucket: ${dtr_s3_bucket}"
  info ">> Calling DTR cluster's API to configure storage"
  HTTP_CODE=$(curl -sk --write-out '%%{http_code}' \
  -u "${ucp_admin_username}":"${ucp_admin_password}" \
  -X PUT "$DTR_URL/api/v0/admin/settings/registry/simple" \
  -H 'content-type: application/json' \
  -d "{\"storage\":{\"delete\":{\"enabled\":true},\"maintenance\":{\"readonly\":{\"enabled\":false}},\"s3\":{\"rootdirectory\":\"\",\"accesskey\":\"${dtr_s3_access_key}\",\"secretkey\":\"${dtr_s3_secret_key}\",\"region\":\"${dtr_s3_region}\",\"regionendpoint\":\"\",\"bucket\":\"${dtr_s3_bucket}\",\"secure\": true}}}")
  CURL_STATUS=$?
  debug "CURL_STATUS: $CURL_STATUS; HTTP_CODE: $HTTP_CODE"
}
