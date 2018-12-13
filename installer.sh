#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o pipefail

# _install_pip() - Install Python Package Manager
function _install_pip {
    if $(pip --version &>/dev/null); then
        sudo apt-get install -y python-dev
        curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
    else
        sudo -E pip install --upgrade pip
    fi
}

# _install_ansible() - Install and Configure Ansible program
function _install_ansible {
    sudo mkdir -p /etc/ansible/
    if $(ansible --version &>/dev/null); then
        return
    fi
    _install_pip
    sudo -E pip install ansible
}

# _install_docker() - Download and install docker-engine
function _install_docker {
    local max_concurrent_downloads=${1:-3}

    if $(docker version &>/dev/null); then
        return
    fi
    sudo apt-get install -y software-properties-common linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates curl
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce

    sudo mkdir -p /etc/systemd/system/docker.service.d
    if [ $http_proxy ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
        echo "Environment=\"HTTP_PROXY=$http_proxy\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
    fi
    if [ $https_proxy ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf
        echo "Environment=\"HTTPS_PROXY=$https_proxy\"" | sudo tee --append /etc/systemd/system/docker.service.d/https-proxy.conf
    fi
    if [ $no_proxy ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf
        echo "Environment=\"NO_PROXY=$no_proxy\"" | sudo tee --append /etc/systemd/system/docker.service.d/no-proxy.conf
    fi
    sudo systemctl daemon-reload
    echo "DOCKER_OPTS=\"-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --max-concurrent-downloads $max_concurrent_downloads \"" | sudo tee --append /etc/default/docker
    sudo usermod -aG docker $USER

    sudo systemctl restart docker
    sleep 10
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    local dest_folder=/opt
    version=$(grep "kubespray_version" ${krd_playbooks}/krd-vars.yml | awk -F ': ' '{print $2}')
    local_release_dir=$(grep "local_release_dir" $krd_inventory_folder/group_vars/k8s-cluster.yml | awk -F "\"" '{print $2}')
    local tarball=v$version.tar.gz

    sudo apt-get install -y sshpass
    _install_docker
    _install_ansible
    wget https://github.com/kubernetes-sigs/kubespray/archive/$tarball
    sudo tar -C $dest_folder -xzf $tarball
    sudo mv $dest_folder/kubespray-$version/ansible.cfg /etc/ansible/ansible.cfg
    sudo chown -R $USER $dest_folder/kubespray-$version
    sudo mkdir -p ${local_release_dir}/containers
    rm $tarball

    sudo -E pip install -r $dest_folder/kubespray-$version/requirements.txt
    rm -f $krd_inventory_folder/group_vars/all.yml 2> /dev/null
    if [[ -n "${verbose}" ]]; then
        echo "kube_log_level: 5" | tee $krd_inventory_folder/group_vars/all.yml
    else
        echo "kube_log_level: 2" | tee $krd_inventory_folder/group_vars/all.yml
    fi
    echo "kubeadm_enabled: true" | tee --append $krd_inventory_folder/group_vars/all.yml
    if [[ -n "${http_proxy}" ]]; then
        echo "http_proxy: \"$http_proxy\"" | tee --append $krd_inventory_folder/group_vars/all.yml
    fi
    if [[ -n "${https_proxy}" ]]; then
        echo "https_proxy: \"$https_proxy\"" | tee --append $krd_inventory_folder/group_vars/all.yml
    fi
    ansible-playbook $verbose -i $krd_inventory $dest_folder/kubespray-$version/cluster.yml --become --become-user=root | sudo tee $log_folder/setup-kubernetes.log

    # Configure environment
    mkdir -p $HOME/.kube
    cp $krd_inventory_folder/artifacts/admin.conf $HOME/.kube/config
}

# install_addons() - Install Kubenertes AddOns
function install_addons {
    echo "Installing Kubernetes AddOns"
    _install_ansible
    sudo ansible-galaxy install $verbose -r $krd_folder/galaxy-requirements.yml --ignore-errors

    ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-krd.yml | sudo tee $log_folder/setup-krd.log
    for addon in ${KRD_ADDONS:-ovn-kubernetes nfd istio kured}; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-${addon}.yml | sudo tee $log_folder/setup-${addon}.log
        if [[ "${testing_enabled}" == "true" ]]; then
            pushd $krd_tests
            bash ${addon}.sh
            popd
        fi
    done
}

# _print_kubernetes_info() - Prints the login Kubernetes information
function _print_kubernetes_info {
    if ! $(kubectl version &>/dev/null); then
        return
    fi
    # Expose Dashboard using NodePort
    node_port=30080
    KUBE_EDITOR="sed -i \"s|type\: ClusterIP|type\: NodePort|g\"" kubectl -n kube-system edit service kubernetes-dashboard
    KUBE_EDITOR="sed -i \"s|nodePort\: .*|nodePort\: $node_port|g\"" kubectl -n kube-system edit service kubernetes-dashboard

    master_ip=$(kubectl cluster-info | grep "Kubernetes master" | awk -F ":" '{print $2}')

    printf "Kubernetes Info\n===============\n" > $k8s_info_file
    echo "Dashboard URL: https:$master_ip:$node_port" >> $k8s_info_file
    echo "Admin user: kube" >> $k8s_info_file
    echo "Admin password: secret" >> $k8s_info_file
}

if ! sudo -n "true"; then
    echo ""
    echo "passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

if [[ "${KRD_DEBUG}" == "true" ]]; then
    set -o xtrace
    verbose="-vvv"
fi

# Configuration values
log_folder=/var/log/krd
krd_folder=$(pwd)
export krd_inventory_folder=$krd_folder/inventory
krd_inventory=$krd_inventory_folder/hosts.ini
krd_playbooks=$krd_folder/playbooks
krd_tests=$krd_folder/tests
k8s_info_file=$krd_folder/k8s_info.log
testing_enabled=${KRD_ENABLE_TESTS:-false}

sudo mkdir -p $log_folder

# Install dependencies
# Setup proxy variables
if [ -f $krd_folder/sources.list ]; then
    sudo mv /etc/apt/sources.list /etc/apt/sources.list.backup
    sudo cp $krd_folder/sources.list /etc/apt/sources.list
fi
sudo apt-get update
install_k8s
install_addons
_print_kubernetes_info
