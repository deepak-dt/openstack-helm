#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images memcached

#NOTE: Deploy command
helm install ./memcached \
    --namespace=openstack \
    --name=memcached

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status memcached
