#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images opencontrail

#NOTE: Deploy command
helm install ./opencontrail \
    --namespace=openstack \
    --name=opencontrail

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status opencontrail
