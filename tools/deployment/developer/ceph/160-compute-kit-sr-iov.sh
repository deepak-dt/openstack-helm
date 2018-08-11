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

SRIOV_DEV1=enp3s0f0
SRIOV_DEV2=enp66s0f1
OVSBR=vlan92
BREXBR=vlan96
OSH_EXTRA_HELM_ARGS="--values=./tools/overrides/releases/ocata/loci.yaml"

#NOTE: Deploy nova
#: ${OSH_EXTRA_HELM_ARGS:=""}
tee /tmp/nova.yaml << EOF
network:
  backend:
   - openvswitch
   - sriov
conf:
  nova:
    DEFAULT:
      debug: True
      linuxnet_interface_driver: nova.network.linux_net.LinuxOVSInterfaceDriver
      vcpu_pin_set: 4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61
      vif_plugging_is_fatal: False
      vif_plugging_timeout: 30
    pci:
      alias: '{"name": "numa0", "capability_type": "pci", "product_id": "10fb", "vendor_id": "8086", "device_type": "type-PCI", "numa_policy": "required"}'
      passthrough_whitelist: |
        [{"address": "0000:03:10.0", "physical_network": "physnet1", "trusted": "true"}, {"address": "0000:03:10.2", "physical_network": "physnet1", "trusted": "true"}, {"address": "0000:03:10.4", "physical_network": "physnet1","trusted":"true"}, {"address": "0000:03:10.6", "physical_network": "physnet1","trusted": "true"}, {"address": "0000:03:11.0", "physical_network": "physnet1","trusted":"true"}, {"address": "0000:03:11.2", "physical_network": "physnet1","trusted":"true"}, {"address": "0000:03:11.4", "physical_network": "physnet1","trusted":"true"}, {"address": "0000:03:11.6", "physical_network": "physnet1"}, {"address": "0000:03:12.0", "physical_network": "physnet1"}, {"address": "0000:03:12.2", "physical_network": "physnet1"}, {"address": "0000:03:12.4", "physical_network": "physnet1"}, {"address": "0000:03:12.6", "physical_network": "physnet1"}, {"address": "0000:03:13.0", "physical_network": "physnet1"}, {"address": "0000:03:13.2", "physical_network": "physnet1"}, {"address": "0000:03:13.4", "physical_network": "physnet1"}, {"address": "0000:03:13.6", "physical_network": "physnet1"}, {"address": "0000:03:14.0", "physical_network": "physnet1"}, {"address": "0000:03:14.2", "physical_network": "physnet1"}, {"address": "0000:03:14.4", "physical_network": "physnet1"}, {"address": "0000:03:14.6", "physical_network": "physnet1"}, {"address": "0000:03:15.0", "physical_network": "physnet1"}, {"address": "0000:03:15.2", "physical_network": "physnet1"}, {"address": "0000:03:15.4", "physical_network": "physnet1"}, {"address": "0000:03:15.6", "physical_network": "physnet1"}, {"address": "0000:03:16.0", "physical_network": "physnet1"}, {"address": "0000:03:16.2", "physical_network": "physnet1"}, {"address": "0000:03:16.4", "physical_network": "physnet1"}, {"address": "0000:03:16.6", "physical_network": "physnet1"}, {"address": "0000:03:17.0", "physical_network": "physnet1"}, {"address": "0000:03:17.2", "physical_network": "physnet1"}, {"address": "0000:03:17.4", "physical_network": "physnet1"}, {"address": "0000:03:17.6", "physical_network": "physnet1"}, {"address": "0000:42:10.1", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:10.3", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:10.5", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:10.7", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:11.1", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:11.3", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:11.5", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:11.7", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:12.1", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:12.3", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:12.5", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:12.7", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:13.1", "physical_network": "physnet2","trusted": "true"}, {"address": "0000:42:13.3", "physical_network": "physnet2"}, {"address": "0000:42:13.5", "physical_network": "physnet2"}, {"address": "0000:42:13.7", "physical_network": "physnet2"}, {"address": "0000:42:14.1", "physical_network": "physnet2"}, {"address": "0000:42:14.3", "physical_network": "physnet2"}, {"address": "0000:42:14.5", "physical_network": "physnet2"}, {"address": "0000:42:14.7", "physical_network": "physnet2"}, {"address": "0000:42:15.1", "physical_network": "physnet2"}, {"address": "0000:42:15.3", "physical_network": "physnet2"}, {"address": "0000:42:15.5", "physical_network": "physnet2"}, {"address": "0000:42:15.7", "physical_network": "physnet2"}, {"address": "0000:42:16.1", "physical_network": "physnet2"}, {"address": "0000:42:16.3", "physical_network": "physnet2"}, {"address": "0000:42:16.5", "physical_network": "physnet2"}, {"address": "0000:42:16.7", "physical_network": "physnet2"}, {"address": "0000:42:17.1", "physical_network": "physnet2"}, {"address": "0000:42:17.3", "physical_network": "physnet2"}, {"address": "0000:42:17.5", "physical_network": "physnet2"}, {"address": "0000:42:17.7", "physical_network": "physnet2"}]
    filter_scheduler:
      enabled_filters: "RetryFilter, AvailabilityZoneFilter, RamFilter, ComputeFilter, ComputeCapabilitiesFilter, ImagePropertiesFilter, ServerGroupAntiAffinityFilter, ServerGroupAffinityFilter, PciPassthroughFilter, NUMATopologyFilter, DifferentHostFilter, SameHostFilter, JsonFilter, AggregateTypeAffinityFilter, JsonMetaDataCountFilter"
EOF

if [ "x$(systemd-detect-virt)" == "xnone" ]; then
  echo 'OSH is not being deployed in virtualized environment'
  helm upgrade --install nova ./nova \
      --namespace=openstack \
      --values /tmp/nova.yaml \
      ${OSH_EXTRA_HELM_ARGS}
else
  echo 'OSH is being deployed in virtualized environment, using qemu for nova'
  helm upgrade --install nova ./nova \
      --namespace=openstack \
      --set conf.nova.libvirt.virt_type=qemu \
      --values /tmp/nova.yaml \
      ${OSH_EXTRA_HELM_ARGS}
fi

#NOTE: Deploy neutron
tee /tmp/neutron.yaml << EOF
network:
  backend:
   - openvswitch
   - sriov
  interface:
    tunnel: docker0
    sriov:
      - device: ${SRIOV_DEV1}
        num_vfs: 32
        promisc: false
      - device: ${SRIOV_DEV2}
        num_vfs: 32
        promisc: false
  auto_bridge_add:
    br-physnet92: ${OVSBR}
    br-ex: ${BREXBR}
conf:
  neutron:
    DEFAULT:
      debug: True
      l3_ha: False
      min_l3_agents_per_router: 1
      max_l3_agents_per_router: 1
      l3_ha_network_type: vxlan
      dhcp_agents_per_network: 1
      service_plugins: trunk
  plugins:
    ml2_conf:
      ml2:
        mechanism_drivers: l2population,openvswitch,sriovnicswitch
        type_drivers: vlan,flat,vxlan
        extension_drivers: port_security
        tenant_network_types: vxlan
      ml2_type_flat:
        flat_networks: public
#        type_drivers: vlan,flat,vxlan
#        mechanism_drivers: openvswitch,sriovnicswitch,l2population
#        tenant_network_types: vxlan
      ml2_type_vlan:
#        network_vlan_ranges: physnet1:20:2025,physnet2:20:2025,physnet3:96:96
        network_vlan_ranges: physnet1:20:2025,physnet2:20:2025,physnet92:92:92,physnet96:96:96
    #NOTE(portdirect): for clarity we include options for all the neutron
    # backends here.
    openvswitch_agent:
#      DEFAULT:
#        ovs_use_veth: True 
      agent:
        tunnel_types: vxlan
      ovs:
        bridge_mappings: "public:br-ex,physnet92:br-physnet92"
    linuxbridge_agent:
      linux_bridge:
        bridge_mappings: "public:br-ex,physnet1:br-physnet1"
    sriov_agent:
      securitygroup:
        firewall_driver: neutron.agent.firewall.NoopFirewallDriver
      sriov_nic:
        physical_device_mappings: physnet1:${SRIOV_DEV1},physnet2:${SRIOV_DEV2}
        exclude_devices: null
EOF
kubectl label node cab24-r820-14 --overwrite=true sriov=enabled
kubectl label node cab24-r820-15 --overwrite=true sriov=enabled

helm upgrade --install neutron ./neutron \
    --namespace=openstack \
    --values=/tmp/neutron.yaml \
    ${OSH_EXTRA_HELM_ARGS}

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
export OS_CLOUD=openstack_helm
openstack service list
sleep 30 #NOTE(portdirect): Wait for ingress controller to update rules and restart Nginx
openstack hypervisor list
openstack network agent list
