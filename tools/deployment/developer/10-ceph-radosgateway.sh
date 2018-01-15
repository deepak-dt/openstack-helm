#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images ceph

#NOTE: Deploy command
WORK_DIR=$(pwd)
helm install --namespace=openstack ${WORK_DIR}/ceph --name=radosgw-openstack \
   --set endpoints.identity.namespace=openstack \
   --set endpoints.object_store.namespace=ceph \
   --set endpoints.ceph_mon.namespace=ceph \
   --set ceph.rgw_keystone_auth=true \
   --set network.public=172.17.0.1/16 \
   --set network.cluster=172.17.0.1/16 \
   --set deployment.storage_secrets=false \
   --set deployment.ceph=false \
   --set deployment.rbd_provisioner=false \
   --set deployment.client_secrets=false \
   --set deployment.rgw_keystone_user_and_endpoints=true \
   --values=${WORK_DIR}/tools/overrides/mvp/ceph.yaml

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh openstack

#NOTE: Validate Deployment info
helm status radosgw-openstack
export OS_CLOUD=openstack_helm
openstack service list
openstack container create 'mygreatcontainer'
curl -L -o /tmp/important-file.jpg https://imgflip.com/s/meme/Cute-Cat.jpg
openstack object create --name 'superimportantfile.jpg' 'mygreatcontainer' /tmp/important-file.jpg
