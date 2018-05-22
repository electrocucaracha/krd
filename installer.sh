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
log_folder=/var/log/
k8s_info_file=$log_folder/k8s_info.log
kubectl_version=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
ansible_inventory=/etc/kubespray/hosts.ini
kubespray_config=/etc/kubespray/k8s-cluster.yml
NIC=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
IP_ADDRESS=$(ifconfig $NIC | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2)

# Install dependencies
apt-get update
apt-get install -y git sshpass python-dev
curl -sL https://bootstrap.pypa.io/get-pip.py | python
pip install --upgrade pip

# Install kubectl
if ! $(kubectl version &>/dev/null); then
    rm -rf ~/.kube
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$kubectl_version/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    mkdir ~/.kube
fi

# Deploy Kubernetes using kubespray tool
git clone https://github.com/kubernetes-incubator/kubespray $src_folder
pushd $src_folder
pip install -r requirements.txt
rm -rf inventory/*
mkdir -p inventory/group_vars
cp $ansible_inventory ./inventory/inventory.cfg
cp $kubespray_config ./inventory/group_vars/
if [ $http_proxy ]; then
    sed -i "s|#http_proxy: \"\"|http_proxy: \"$http_proxy\"|g" ./inventory/group_vars/k8s-cluster.yml
fi
if [ $https_proxy ]; then
    sed -i "s|#https_proxy: \"\"|https_proxy: \"$https_proxy\"|g" ./inventory/group_vars/k8s-cluster.yml
fi
# TODO(electrocucaracha): Create a loop here to wait for nodes
ansible-playbook -vvv -i inventory/inventory.cfg cluster.yml -b | tee $log_folder/setup-kubernetes.log
popd

cp /root/admin.conf /root/.kube/config

printf "Kubernetes Info\n===============\n" > $k8s_info_file
echo "Dashboard URL: https://$IP_ADDRESS:$(kubectl get service -n kube-system |grep kubernetes-dashboard | awk '{print $5}' |awk -F "[:/]" '{print $1}')" >> $k8s_info_file
echo "Admin user: kube" >> $k8s_info_file
echo "Admin password: secret" >> $k8s_info_file

mkdir -p /etc/ansible/
cat <<EOL > /etc/ansible/ansible.cfg
[defaults]
host_key_checking = false
EOL
ansible-galaxy install -r /etc/kubespray/galaxy-requirements.yml

ansible-playbook -vvv -i /etc/kubespray/hosts.ini /opt/vagrant-k8s/playbooks/configure-ovn.yml | tee $log_folder/setup-ovn.log
ansible-playbook -vvv -i /etc/kubespray/hosts.ini /opt/vagrant-k8s/playbooks/configure-ovn-kubernetes.yml | tee $log_folder/setup-ovn-kubernetes.log
