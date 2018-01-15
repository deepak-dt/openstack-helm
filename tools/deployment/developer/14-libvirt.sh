#!/bin/bash

#NOTE: Pull images and lint chart
make pull-images libvirt

#NOTE: Deploy command
helm install ./libvirt \
  --namespace=openstack \
  --name=libvirt

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status libvirt
