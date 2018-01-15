#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images horizon

#NOTE: Deploy command
helm install ./horizon \
    --namespace=openstack \
    --name=horizon \
    --set network.node_port.enabled=true \
    --set network.node_port.port=31000

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status horizon
