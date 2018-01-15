#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images rabbitmq

#NOTE: Deploy command
helm install ./rabbitmq \
    --namespace=openstack \
    --name=rabbitmq

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status rabbitmq
