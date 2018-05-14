#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

src_folder=/opt/kubespray

apt-get update
apt-get install -y git sshpass

git clone https://github.com/kubernetes-incubator/kubespray $src_folder
curl -sL https://bootstrap.pypa.io/get-pip.py | python
pip install --upgrade pip
pushd $src_folder
pip install -r requirements.txt
rm -rf inventory/*
mkdir -p inventory/group_vars
cp /etc/kubespray/hosts.ini ./inventory/inventory.cfg
cp /etc/kubespray/k8s-cluster.yml ./inventory/group_vars/

if [ $http_proxy ]; then
    sed -i "s|#http_proxy: \"\"|http_proxy: \"$http_proxy\"|g" ./inventory/group_vars/k8s-cluster.yml
fi
if [ $https_proxy ]; then
    sed -i "s|#https_proxy: \"\"|https_proxy: \"$https_proxy\"|g" ./inventory/group_vars/k8s-cluster.yml
fi
if [ $no_proxy ]; then
    sed -i "s|#no_proxy: \"\"|no_proxy: \"$no_proxy\"|g" ./inventory/group_vars/k8s-cluster.yml
fi

# TODO(electrocucaracha): Create a wait loop here

ansible-playbook -vvv -i inventory/inventory.cfg cluster.yml -b | tee setup-kubernetes.log
popd

# TODO(electrocucaracha): Install ovn-kubernetes
