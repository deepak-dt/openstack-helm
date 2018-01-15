#!/bin/bash
set -xe

#NOTE: Pull images and lint chart
make pull-images ceph

#NOTE: Deploy command
WORK_DIR=$(pwd)
helm install --namespace=ceph ${WORK_DIR}/ceph --name=ceph \
    --set endpoints.identity.namespace=openstack \
    --set endpoints.object_store.namespace=ceph \
    --set endpoints.ceph_mon.namespace=ceph \
    --set ceph.rgw_keystone_auth=true \
    --set network.public=172.17.0.1/16 \
    --set network.cluster=172.17.0.1/16 \
    --set deployment.storage_secrets=true \
    --set deployment.ceph=true \
    --set deployment.rbd_provisioner=true \
    --set deployment.client_secrets=false \
    --set deployment.rgw_keystone_user_and_endpoints=false \
    --set bootstrap.enabled=true \
    --values=${WORK_DIR}/tools/overrides/mvp/ceph.yaml

#NOTE: Wait for deploy
./tools/deployment/developer/wait-for-pods.sh ceph

#NOTE: Validate deploy
MON_POD=$(kubectl get pods \
  --namespace=ceph \
  --selector="application=ceph" \
  --selector="component=mon" \
  --no-headers | awk '{ print $1; exit }')
kubectl exec -n ceph ${MON_POD} -- ceph -s
