#!/bin/bash

#NOTE: Pull images and lint chart
make pull-images nova
make pull-images neutron

#NOTE: Deploy nova
if [ "x$(systemd-detect-virt)" == "xnone" ]; then
  echo 'OSH is not being deployed in virtualized environment'
  helm install ./nova \
      --namespace=openstack \
      --name=nova
else
  echo 'OSH is being deployed in virtualized environment, using qemu for nova'
  helm install ./nova \
      --namespace=openstack \
      --name=nova \
      --set conf.nova.libvirt.virt_type=qemu
fi

#NOTE: Deploy neutron
helm install ./neutron \
    --namespace=openstack \
    --name=neutron \

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
export OS_CLOUD=openstack_helm
openstack service list
sleep 15
openstack hypervisor list
openstack network agent list
