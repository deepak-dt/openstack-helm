#!/bin/bash
set -xe

sudo -H -E pip install python-openstackclient python-heatclient

sudo -H mkdir -p /etc/openstack
cat << EOF | sudo -H tee -a /etc/openstack/clouds.yaml
clouds:
  openstack_helm:
    region_name: RegionOne
    identity_api_version: 3
    auth:
      username: 'admin'
      password: 'password'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
      auth_url: 'http://keystone.openstack.svc.cluster.local/v3'
EOF
sudo -H chown -R $(id -un): /etc/openstack

#NOTE: Build charts
make all
