#!/bin/bash

# Copyright 2018 The Openstack-Helm Authors.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

set -xe

: ${OSH_EXT_NET_NAME:="public"}
: ${OSH_EXT_SUBNET_NAME:="public-subnet"}
: ${OSH_EXT_SUBNET:="172.24.4.0/24"}
: ${OSH_BR_EX_ADDR:="172.24.4.0/24"}
: ${OSH_PRIVATE_SUBNET_POOL:="11.0.0.0/8"}
: ${OSH_PRIVATE_SUBNET_POOL_NAME:="shared-default-subnetpool"}
: ${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX:="24"}
: ${OSH_VM_KEY_STACK:="heat-vm-key"}
: ${OSH_PRIVATE_SUBNET:="11.0.0.0/24"}

# Shaker conf params
: ${OS_USERNAME:="admin"}
: ${OS_PASSWORD:="password"}
: ${OS_AUTH_URL:="http://keystone.openstack.svc.cluster.local/v3"}
: ${OS_PROJECT_NAME:="admin"}
: ${OS_REGION_NAME:="RegionOne"}
: ${EXTERNAL_NETWORK_NAME:=$OSH_EXT_NET_NAME}
: ${SCENARIO:="/opt/shaker/shaker/scenarios/openstack/full_l2.yaml"}
: ${AVAILABILITY_ZONE:="nova"}
: ${REPORT_FILE:="/tmp/shaker-result.html"}
: ${OUTPUT_FILE:="/tmp/shaker-result.json"}
: ${FLAVOR_ID:="shaker-flavor"}
: ${IMAGE_NAME:=""}
: ${SERVER_ENDPOINT_INTF:="eth0"}

: ${EXECUTE_TEST:=""}

#NOTE: Pull images and lint chart
make pull-images shaker

#NOTE: Deploy command
export OS_CLOUD=openstack_helm

IMAGE_NAME=$(openstack image show -f value -c name \
  $(openstack image list -f csv | awk -F ',' '{ print $2 "," $1 }' | \
  grep "^\"Cirros" | head -1 | awk -F ',' '{ print $2 }' | tr -d '"'))

FLAVOR_ID="m1.tiny"

export stack_exists=`openstack stack list | grep heat-public-net-deployment | awk '{print $4}'`

if [ -z $stack_exists ]; then
openstack stack create --wait \
  --parameter network_name=${OSH_EXT_NET_NAME} \
  --parameter physical_network_name=${OSH_EXT_NET_NAME} \
  --parameter subnet_name=${OSH_EXT_SUBNET_NAME} \
  --parameter subnet_cidr=${OSH_EXT_SUBNET} \
  --parameter subnet_gateway=${OSH_BR_EX_ADDR%/*} \
  -t ./tools/gate/files/heat-public-net-deployment.yaml \
  heat-public-net-deployment
fi

export stack_exists=`openstack stack list | grep heat-subnet-pool-deployment | awk '{print $4}'`

if [ -z $stack_exists ]; then
openstack stack create --wait \
  --parameter subnet_pool_name=${OSH_PRIVATE_SUBNET_POOL_NAME} \
  --parameter subnet_pool_prefixes=${OSH_PRIVATE_SUBNET_POOL} \
  --parameter subnet_pool_default_prefix_length=${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
  -t ./tools/gate/files/heat-subnet-pool-deployment.yaml \
  heat-subnet-pool-deployment
fi

if [ -z $IMAGE_NAME ]; then
# Install shaker to use shaker-image-builder utility
sudo apt-add-repository "deb http://nova.clouds.archive.ubuntu.com/ubuntu/ trusty multiverse"
sudo apt-get update
sudo apt-get -y install python-dev libzmq-dev
sudo pip install pbr pyshaker

# Export AUTH variables required by shaker-image-builder utility
export OS_USERNAME=${OS_USERNAME}
export OS_PASSWORD=${OS_PASSWORD}
export OS_AUTH_URL=${OS_AUTH_URL}
export OS_PROJECT_NAME=${OS_PROJECT_NAME}
export OS_REGION_NAME=${OS_REGION_NAME}
export EXTERNAL_NETWORK_NAME=${EXTERNAL_NETWORK_NAME}

# Run shaker-image-builder utility to build shaker image
# For debug mode
# shaker-image-builder --nocleanup-on-error --debug
# For debug mode - with disk-image-builder mode
# shaker-image-builder --nocleanup-on-error --debug --image-builder-mode dib
shaker-image-builder

IMAGE_NAME=$(openstack image show -f value -c name \
  $(openstack image list -f csv | awk -F ',' '{ print $2 "," $1 }' | \
  grep "^\"shaker" | head -1 | awk -F ',' '{ print $2 }' | tr -d '"'))
fi

FLAVOR_ID=$(openstack flavor show "${FLAVOR_ID}" -f value -c id)
IMAGE_ID=$(openstack image show "${IMAGE_NAME}" -f value -c id)

#NOTE: Deploy shaker pods
tee /tmp/shaker.yaml << EOF
conf:
  script: |
    sed -i -E "s/(accommodation\: \[.+)(.+\])/accommodation\: \[pair, compute_nodes: 1\]/" ${SCENARIO}
    export server_endpoint=\`ip a | grep "global ${SERVER_ENDPOINT_INTF}" | cut -f6 -d' ' | cut -f1 -d'/'\`
    shaker --server-endpoint \$server_endpoint:31999 --config-file /opt/shaker/shaker.conf
    #while true; do
    #   echo `date`
    #   sleep 5
    #done
  shaker:
    shaker:
      DEFAULT:
        debug: true
        cleanup_on_error: false
        compute_nodes: 1
        #server_endpoint: ${SERVER_ENDPOINT}
        report: ${REPORT_FILE}
        output: ${OUTPUT_FILE}
        scenario: ${SCENARIO}
        flavor_name: ${FLAVOR_ID}
        external_net: ${EXTERNAL_NETWORK_NAME}
        image_name: ${IMAGE_ID}
        availability_zone: ${AVAILABILITY_ZONE}
        os_username: ${OS_USERNAME}
        os_password: ${OS_PASSWORD}
        os_auth_url: ${OS_AUTH_URL}
        os_project_name: ${OS_PROJECT_NAME}
        os_region_name: ${OS_REGION_NAME}
EOF

envsubst < /tmp/shaker.yaml

helm upgrade --install shaker ./shaker \
  --namespace=openstack \
  --values=/tmp/shaker.yaml \
  ${OSH_EXTRA_HELM_ARGS} \
  ${OSH_EXTRA_HELM_ARGS_SHAKER}

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack 2400

#NOTE: Validate Deployment info
kubectl get -n openstack jobs --show-all

if [ -n $EXECUTE_TEST ]; then
helm test shaker --timeout 900
fi
