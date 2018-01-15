#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images keystone

#NOTE: Deploy command
helm install ./keystone \
    --namespace=openstack \
    --name=keystone

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status keystone
export OS_CLOUD=openstack_helm
openstack endpoint list
