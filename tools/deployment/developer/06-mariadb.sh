#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images mariadb

#NOTE: Deploy command
helm install ./mariadb \
    --namespace=openstack \
    --name=mariadb \
    --set pod.replicas.server=1

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack 600

#NOTE: Validate Deployment info
helm status mariadb
