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

export OS_CLOUD=openstack_helm

export OSH_EXT_NET_NAME="public"
export OSH_EXT_SUBNET_NAME="public-subnet"
export OSH_EXT_SUBNET="172.24.4.0/24"
export OSH_BR_EX_ADDR="172.24.4.1/24"
export OSH_PRIVATE_NET_NAME="private_net"
export OSH_PRIVATE_SUBNET_NAME="private_subnet"
export OSH_PORT_SECURITY_GROUP="port_security_group"
openstack stack create --wait \
  --parameter network_name=${OSH_EXT_NET_NAME} \
  --parameter physical_network_name=public \
  --parameter subnet_name=${OSH_EXT_SUBNET_NAME} \
  --parameter subnet_cidr=${OSH_EXT_SUBNET} \
  --parameter subnet_gateway=${OSH_BR_EX_ADDR%/*} \
  --parameter private_net=${OSH_PRIVATE_NET_NAME} \
  --parameter private_subnet=${OSH_PRIVATE_SUBNET_NAME} \
  --parameter port_security_group=${OSH_PORT_SECURITY_GROUP} \
  -t ./tools/gate/files/heat-public-net-deploy-external-connectivity.yaml \
  heat-public-net-deployment

export OSH_PRIVATE_SUBNET_POOL="10.0.0.0/8"
export OSH_PRIVATE_SUBNET_POOL_NAME="shared-default-subnetpool"
export OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX="24"
openstack stack create --wait \
  --parameter subnet_pool_name=${OSH_PRIVATE_SUBNET_POOL_NAME} \
  --parameter subnet_pool_prefixes=${OSH_PRIVATE_SUBNET_POOL} \
  --parameter subnet_pool_default_prefix_length=${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
  -t ./tools/gate/files/heat-subnet-pool-deployment.yaml \
  heat-subnet-pool-deployment


export OSH_EXT_NET_NAME="public"
export OSH_VM_KEY_STACK="heat-vm-key"
export OSH_PRIVATE_SUBNET="10.0.0.0/24"

# NOTE(portdirect): We do this fancy, and seemingly pointless, footwork to get
# the full image name for the cirros Image without having to be explicit.
export IMAGE_NAME=$(openstack image show -f value -c name \
  $(openstack image list -f csv | awk -F ',' '{ print $2 "," $1 }' | \
    grep "^\"Cirros" | head -1 | awk -F ',' '{ print $2 }' | tr -d '"'))

export TAAS_TS_IMAGE_NAME="shaker-image-323"

read -p "Uploaded Ubuntu image [$TAAS_TS_IMAGE_NAME]? Press y to continue or n to abort [y/n] : " yn
case $yn in
    [Nn]* ) export TAAS_TS_IMAGE_NAME=$IMAGE_NAME;;
esac

# Setup SSH Keypair in Nova
mkdir -p ${HOME}/.ssh
openstack keypair create --private-key ${HOME}/.ssh/osh_key ${OSH_VM_KEY_STACK}
chmod 600 ${HOME}/.ssh/osh_key

openstack stack create --wait \
    --parameter public_net=${OSH_EXT_NET_NAME} \
    --parameter image="${IMAGE_NAME}" \
    --parameter ssh_key=${OSH_VM_KEY_STACK} \
    --parameter cidr=${OSH_PRIVATE_SUBNET} \
    --parameter dns_nameserver=${OSH_BR_EX_ADDR%/*} \
    --parameter private_net=${OSH_PRIVATE_NET_NAME} \
    --parameter private_subnet=${OSH_PRIVATE_SUBNET_NAME} \
    --parameter port_security_group=${OSH_PORT_SECURITY_GROUP} \
    --parameter vm_port_name='left-port' \
    --parameter vf_vlan_filter='0' \
    --parameter vf_vlan_mirror='' \
    --parameter vf_public_vlans='1,10-20,25,30-45' \
    --parameter vf_private_vlans='54,60-63,72,99' \
    --parameter vf_guest_vlans='1,10-20,25,30-45,54,60-63,72,99' \
    --parameter vf_pci_slot='0000:04:00.0' \
    --parameter pf_pci_slot='0000:04:00.1' \
    --parameter pf_pci_vendor_info='7daf:67bc' \
    --parameter pf_physical_network='sriovnet1' \
    -t ./tools/gate/files/heat-basic-vm-deployment.yaml \
    heat-left-vm-deployment

LEFT_FLOATING_IP=$(openstack stack output show \
    heat-left-vm-deployment \
    floating_ip \
    -f value -c output_value)

openstack stack create --wait \
    --parameter public_net=${OSH_EXT_NET_NAME} \
    --parameter image="${IMAGE_NAME}" \
    --parameter ssh_key=${OSH_VM_KEY_STACK} \
    --parameter cidr=${OSH_PRIVATE_SUBNET} \
    --parameter dns_nameserver=${OSH_BR_EX_ADDR%/*} \
    --parameter private_net=${OSH_PRIVATE_NET_NAME} \
    --parameter private_subnet=${OSH_PRIVATE_SUBNET_NAME} \
    --parameter port_security_group=${OSH_PORT_SECURITY_GROUP} \
    --parameter vm_port_name='right-port' \
    --parameter vf_vlan_filter='0' \
    --parameter vf_vlan_mirror='' \
    --parameter vf_public_vlans='1,10-20,25,30-45' \
    --parameter vf_private_vlans='54,60-63,72,99' \
    --parameter vf_guest_vlans='1,10-20,25,30-45,54,60-63,72,99' \
    --parameter vf_pci_slot='0000:04:00.0' \
    --parameter pf_pci_slot='0000:04:00.1' \
    --parameter pf_pci_vendor_info='7daf:67bc' \
    --parameter pf_physical_network='sriovnet1' \
    -t ./tools/gate/files/heat-basic-vm-deployment.yaml \
    heat-right-vm-deployment

RIGHT_FLOATING_IP=$(openstack stack output show \
    heat-right-vm-deployment \
    floating_ip \
    -f value -c output_value)

openstack stack create --wait \
    --parameter public_net=${OSH_EXT_NET_NAME} \
    --parameter image="${TAAS_TS_IMAGE_NAME}" \
    --parameter ssh_key=${OSH_VM_KEY_STACK} \
    --parameter cidr=${OSH_PRIVATE_SUBNET} \
    --parameter dns_nameserver=${OSH_BR_EX_ADDR%/*} \
    --parameter private_net=${OSH_PRIVATE_NET_NAME} \
    --parameter private_subnet=${OSH_PRIVATE_SUBNET_NAME} \
    --parameter port_security_group=${OSH_PORT_SECURITY_GROUP} \
    --parameter vm_port_name='taas-ts-port' \
    --parameter vf_vlan_filter='0' \
    --parameter vf_vlan_mirror='0,1,10-20,25,30-45' \
    --parameter vf_public_vlans='' \
    --parameter vf_private_vlans='' \
    --parameter vf_guest_vlans='' \
    --parameter vf_pci_slot='0000:04:00.0' \
    --parameter pf_pci_slot='0000:04:00.1' \
    --parameter pf_pci_vendor_info='7daf:67bc' \
    --parameter pf_physical_network='sriovnet1' \
    -t ./tools/gate/files/heat-basic-vm-deployment.yaml \
    heat-taas-ts-vm-deployment

TAAS_TS_FLOATING_IP=$(openstack stack output show \
    heat-taas-ts-vm-deployment \
    floating_ip \
    -f value -c output_value)

function wait_for_ssh_port {
  # Default wait timeout is 300 seconds
  set +x
  end=$(date +%s)
  if ! [ -z $2 ]; then
   end=$((end + $2))
  else
   end=$((end + 300))
  fi
  while true; do
      # Use Nmap as its the same on Ubuntu and RHEL family distros
      nmap -Pn -p22 $1 | awk '$1 ~ /22/ {print $2}' | grep -q 'open' && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo "Could not connect to $1 port 22 in time" && exit -1
  done
  set -x
}
wait_for_ssh_port $LEFT_FLOATING_IP
wait_for_ssh_port $RIGHT_FLOATING_IP
wait_for_ssh_port $TAAS_TS_FLOATING_IP

# SSH into the VM and check it can reach the outside world
ssh-keyscan "$LEFT_FLOATING_IP" >> ~/.ssh/known_hosts
ssh -i ${HOME}/.ssh/osh_key cirros@${LEFT_FLOATING_IP} ping -q -c 1 -W 2 ${OSH_BR_EX_ADDR%/*}

# Check the VM can reach the metadata server
ssh -i ${HOME}/.ssh/osh_key cirros@${LEFT_FLOATING_IP} curl --verbose --connect-timeout 5 169.254.169.254

# Check the VM can reach the keystone server
ssh -i ${HOME}/.ssh/osh_key cirros@${LEFT_FLOATING_IP} curl --verbose --connect-timeout 5 keystone.openstack.svc.cluster.local

# SSH into the VM and check it can reach the outside world
ssh-keyscan "$RIGHT_FLOATING_IP" >> ~/.ssh/known_hosts
ssh -i ${HOME}/.ssh/osh_key cirros@${RIGHT_FLOATING_IP} ping -q -c 1 -W 2 ${OSH_BR_EX_ADDR%/*}

# Check the VM can reach the metadata server
ssh -i ${HOME}/.ssh/osh_key cirros@${RIGHT_FLOATING_IP} curl --verbose --connect-timeout 5 169.254.169.254

# Check the VM can reach the keystone server
ssh -i ${HOME}/.ssh/osh_key cirros@${RIGHT_FLOATING_IP} curl --verbose --connect-timeout 5 keystone.openstack.svc.cluster.local

# SSH into the VM and check it can reach the outside world
ssh-keyscan "$TAAS_TS_FLOATING_IP" >> ~/.ssh/known_hosts
ssh -i ${HOME}/.ssh/osh_key ubuntu@${TAAS_TS_FLOATING_IP} ping -q -c 1 -W 2 ${OSH_BR_EX_ADDR%/*}

# Check the VM can reach the metadata server
ssh -i ${HOME}/.ssh/osh_key ubuntu@${TAAS_TS_FLOATING_IP} curl --verbose --connect-timeout 5 169.254.169.254

# Check the VM can reach the keystone server
ssh -i ${HOME}/.ssh/osh_key ubuntu@${TAAS_TS_FLOATING_IP} curl --verbose --connect-timeout 5 keystone.openstack.svc.cluster.local

openstack stack create --wait \
  --parameter taas_ts_port="taas-ts-port" \
  --parameter left_port="left-port" \
  -t ./tools/gate/files/heat-deploy-taas.yaml \
  heat-taas-deployment
