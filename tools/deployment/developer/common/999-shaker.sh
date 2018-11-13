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

# sudo -H -E su -c 'export OSH_EXT_NET_NAME="public"; \
#                  export OSH_EXT_SUBNET_NAME="public-subnet"; \
#                  export OS_USERNAME="dt967u"; \
#                  export OS_PASSWORD=""; \
#                  export OS_AUTH_URL="https://identity-nc.mtn13b3.cci.att.com:443/v3"; \
#                  export OS_PROJECT_NAME="taas-testing"; \
#                  export OS_REGION_NAME="mtn13b3"; \
#                  export OS_PROJECT_ID=af7dac7909754202a0edc58e663f22fe; \
#                  export OS_PROJECT_DOMAIN_NAME="nc"; \
#                  export OS_USER_DOMAIN_NAME="nc"; \
#                  export OS_IDENTITY_API_VERSION=3; \
#                  export EXTERNAL_NETWORK_NAME="public"; \
#                  export SCENARIO="/opt/shaker/shaker/scenarios/openstack/full_l2.yaml"; \
#                  export AVAILABILITY_ZONE="nova"; \
#                  export REPORT_FILE="/tmp/shaker-result.html"; \
#                  export OUTPUT_FILE="/tmp/shaker-result.json"; \
#                  export FLAVOR_ID="m1.medium"; \
#                  export IMAGE_NAME="shaker-image-450"; \
#                  export SERVER_ENDPOINT_IP=""; \
#                  cd $CURR_WORK/openstack-helm; ./tools/deployment/developer/common/999-shaker.sh ${OSH_EXTRA_HELM_ARGS}' ${username}

set -xe

: ${OSH_EXT_NET_NAME:="public"}
: ${OSH_EXT_SUBNET_NAME:="public-subnet"}
: ${OSH_EXT_SUBNET:="172.24.4.0/24"}
: ${OSH_BR_EX_ADDR:="172.24.4.1/24"}
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
: ${OS_USER_DOMAIN_NAME:="Default"}
: ${OS_PROJECT_DOMAIN_NAME:="Default"}
: ${OS_PROJECT_ID:=""}
: ${EXTERNAL_NETWORK_NAME:=$OSH_EXT_NET_NAME}
: ${SCENARIO:="/opt/shaker/shaker/scenarios/openstack/full_l2.yaml"}
: ${AVAILABILITY_ZONE:="nova"}
: ${OS_IDENTITY_API_VERSION:="3"}
: ${OS_INTERFACE:="public"}

: ${REPORT_FILE:="/tmp/shaker-result.html"}
: ${OUTPUT_FILE:="/tmp/shaker-result.json"}
: ${FLAVOR_ID:="shaker-flavor"}
: ${IMAGE_NAME:="shaker-image"}
: ${SERVER_ENDPOINT_IP:=""}
: ${SERVER_ENDPOINT_INTF:="eth0"}
: ${SHAKER_PORT:=31999}
: ${COMPUTE_NODES:=1}

: ${EXECUTE_TEST:="true"}
: ${DEBUG:="true"}
: ${CLEANUP_ON_ERROR:="true"}


#NOTE: Pull images and lint chart
make pull-images shaker

#NOTE: Deploy command

# Export AUTH variables required by shaker-image-builder utility
export OS_USERNAME=${OS_USERNAME}
export OS_PASSWORD=${OS_PASSWORD}
export OS_AUTH_URL=${OS_AUTH_URL}
export OS_PROJECT_NAME=${OS_PROJECT_NAME}
export OS_REGION_NAME=${OS_REGION_NAME}
export EXTERNAL_NETWORK_NAME=${EXTERNAL_NETWORK_NAME}
export OS_PROJECT_ID=${OS_PROJECT_ID}

if [ $OS_IDENTITY_API_VERSION = "3" ]; then
export OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME}
export OS_USER_DOMAIN_NAME=${OS_USER_DOMAIN_NAME}
else
export OS_PROJECT_DOMAIN_NAME=
export OS_USER_DOMAIN_NAME=
fi

export stack_exists=`openstack network list | grep ${OSH_EXT_NET_NAME} | awk '{print $4}'`

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

default_sec_grp_id=`openstack security group list --project ${OS_PROJECT_NAME} | grep default | awk '{split(\$0,a,"|"); print a[2]}'`
for sg in $default_sec_grp_id
do
  icmp=`openstack security group rule list $sg | grep icmp | awk '{split(\$0,a,"|"); print a[2]}'`
  if [ "${icmp}" = "" ]; then openstack security group rule create --proto icmp $sg; fi
  shaker=`openstack security group rule list $sg | grep tcp | grep ${SHAKER_PORT} | awk '{split(\$0,a,"|"); print a[2]}'`
  if [ "${shaker}" = "" ]; then openstack security group rule create --proto tcp --dst-port ${SHAKER_PORT} $sg; fi
done

IMAGE_NAME=$(openstack image show -f value -c name \
  $(openstack image list -f csv | awk -F ',' '{ print $2 "," $1 }' | \
  grep "${IMAGE_NAME}" | head -1 | awk -F ',' '{ print $2 }' | tr -d '"'))

if [ -z $IMAGE_NAME ]; then
# Install shaker to use shaker-image-builder utility
sudo apt-add-repository "deb http://nova.clouds.archive.ubuntu.com/ubuntu/ trusty multiverse"
sudo apt-get update
sudo apt-get -y install python-dev libzmq-dev
sudo pip install pbr pyshaker

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

#NOTE: Deploy shaker pods
tee /tmp/shaker.yaml << EOF
shaker:
  controller:
    external_ip: ${SERVER_ENDPOINT_IP}
images:
  tags:
    shaker_run_tests: docker.io/performa/shaker:latest
conf:
  script: |
    sed -i -E "s/(accommodation\: \[.+)(.+\])/accommodation\: \[pair, compute_nodes: 1\]/" ${SCENARIO}

    if [ -z ${SERVER_ENDPOINT_IP} ]; then
    export server_endpoint=\`ip a | grep "global ${SERVER_ENDPOINT_INTF}" | cut -f6 -d' ' | cut -f1 -d'/'\`
    else
    export server_endpoint=${SERVER_ENDPOINT_IP}
    fi

    echo ===========================
    printenv | grep -i os_

    echo ==========  SHAKER CONF PARAMETERS  =================
    cat /opt/shaker/shaker.conf
    echo =====================================================

    env -i HOME="$HOME" bash -l -c "printenv; shaker --server-endpoint \$server_endpoint:${SHAKER_PORT} --config-file /opt/shaker/shaker.conf"

  shaker:
    shaker:
      DEFAULT:
        debug: ${DEBUG}
        cleanup_on_error: ${CLEANUP_ON_ERROR}
        scenario_compute_nodes: ${COMPUTE_NODES}
        report: ${REPORT_FILE}
        output: ${OUTPUT_FILE}
        scenario: ${SCENARIO}
        flavor_name: ${FLAVOR_ID}
        external_net: ${EXTERNAL_NETWORK_NAME}
        image_name: ${IMAGE_NAME}
        scenario_availability_zone: ${AVAILABILITY_ZONE}
        os_username: ${OS_USERNAME}
        os_password: ${OS_PASSWORD}
        os_auth_url: ${OS_AUTH_URL}
        os_project_name: ${OS_PROJECT_NAME}
        os_region_name: ${OS_REGION_NAME}
        os_identity_api_version: ${OS_IDENTITY_API_VERSION}
        os_interface: ${OS_INTERFACE}
EOF

if [ $OS_IDENTITY_API_VERSION = "3" ]; then
tee /tmp/shaker.yaml << EOF
        os_project_domain_name: ${OS_PROJECT_DOMAIN_NAME}
        os_user_domain_name: ${OS_USER_DOMAIN_NAME}
EOF
fi

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
helm test shaker --timeout 2700
fi
