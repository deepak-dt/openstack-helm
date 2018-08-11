#!/bin/bash

# Copyright 2017 The Openstack-Helm Authors.
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

#NOTE: Pull images and lint chart
make pull-images nova
make pull-images neutron

export TAAS_COMPUTE_1='osh-aio'
export TAAS_COMPUTE_2='osh-aio'

OSH_EXTRA_HELM_ARGS="--values=./tools/overrides/releases/ocata/loci.yaml"

#NOTE: Deploy nova
: ${OSH_EXTRA_HELM_ARGS:=""}

#NOTE: Deploy neutron
tee /tmp/neutron.yaml << EOF
network:
  interface:
    tunnel: docker0
conf:
  neutron:
    DEFAULT:
      l3_ha: False
      min_l3_agents_per_router: 1
      max_l3_agents_per_router: 1
      l3_ha_network_type: vxlan
      dhcp_agents_per_network: 1
      service_plugins: trunk,taas
  plugins:
    ml2_conf:
      ml2_type_flat:
        flat_networks: public
    #NOTE(portdirect): for clarity we include options for all the neutron
    # backends here.
    openvswitch_agent:
      agent:
        tunnel_types: vxlan
      ovs:
        bridge_mappings: public:br-ex
    linuxbridge_agent:
      linux_bridge:
        bridge_mappings: public:br-ex
EOF

kubectl label node $TAAS_COMPUTE_1 --overwrite=true taas=enabled
kubectl label node $TAAS_COMPUTE_2 --overwrite=true taas=enabled

helm upgrade --install neutron ./neutron \
    --namespace=openstack \
    --values=/tmp/neutron.yaml \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_NEUTRON}

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
export OS_CLOUD=openstack_helm
openstack service list
sleep 30 #NOTE(portdirect): Wait for ingress controller to update rules and restart Nginx
openstack hypervisor list
openstack network agent list
