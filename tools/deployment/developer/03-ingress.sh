#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images ingress

#NOTE: Deploy command
helm install ./ingress \
  --namespace=openstack \
  --name=ingress

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Display info
helm status ingress
