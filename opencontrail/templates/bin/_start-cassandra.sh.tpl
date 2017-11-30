#!/bin/bash

# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

verify_cassandra () {
iterations=$1
sleep=$2
count=0
up=false

while [ $up = 'false' ] && [ $count -le $iterations ]; do
  let count=$count+1 

if [[ $(nodetool status | grep $POD_IP) == *"UN"* ]]; then
    echo "UP";
    up='true'
else
    echo "Not Up $count";
fi

  sleep $sleep
done

if [ $up = 'false' ]
then
  exit 1
fi
}

CASSANDRA_CONF_DIR=/etc/cassandra
CASSANDRA_CFG=$CASSANDRA_CONF_DIR/cassandra.yaml
CASSANDRA_ENV=$CASSANDRA_CONF_DIR/cassandra-env.sh
CASSANDRA_CFG_TEMP=`mktemp`
CASSANDRA_DATA=${CASSANDRA_DATA:-'/var/lib/cassandra'}

CASSANDRA_SEEDS=${CASSANDRA_SEEDS:-'127.0.0.1'}
CASSANDRA_CLUSTER_NAME=${CASSANDRA_CLUSTER_NAME:-'Test Cluster'}
CASSANDRA_LISTEN_ADDRESS=${POD_IP:-127.0.0.1}
CASSANDRA_BROADCAST_ADDRESS=${POD_IP:-127.0.0.1}
CASSANDRA_BROADCAST_RPC_ADDRESS=${POD_IP:-127.0.0.1}


chmod 700 "${CASSANDRA_DATA}"
chown -c -R cassandra "${CASSANDRA_DATA}" "${CASSANDRA_CONF_DIR}"
cp $CASSANDRA_CFG $CASSANDRA_CFG_TEMP

for yaml in \
  broadcast_address \
  broadcast_rpc_address \
  cluster_name \
  listen_address \
  ; do
  var="CASSANDRA_${yaml^^}"
  val="${!var}"
  if [ "$val" ]; then
    sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CFG_TEMP"
  fi
done

sed -ri 's/- seeds:.*/- seeds: "'"$CASSANDRA_SEEDS"'"/' $CASSANDRA_CFG_TEMP

sed -i "s/^#MAX_HEAP_SIZE=.*/MAX_HEAP_SIZE=${MAX_HEAP_SIZE}/g" $CASSANDRA_ENV
sed -i "s/^#HEAP_NEWSIZE=.*/HEAP_NEWSIZE=${HEAP_NEWSIZE}/g" $CASSANDRA_ENV

cp $CASSANDRA_CFG_TEMP $CASSANDRA_CFG

service cassandra start

#verify 30 times, sleep 5
verify_cassandra 30 5




sleep inf
