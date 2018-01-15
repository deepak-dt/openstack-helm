#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images glance

#NOTE: Deploy command
GLANCE_BACKEND="radosgw" # NOTE(portdirect), this could be: radosgw, rbd, swift or pvc
helm install ./glance \
  --namespace=openstack \
  --name=glance \
  --set storage=${GLANCE_BACKEND}

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack 600

#NOTE: Validate Deployment info
helm status glance
export OS_CLOUD=openstack_helm
openstack service list
sleep 15
openstack image list
openstack image show 'Cirros 0.3.5 64-bit'
