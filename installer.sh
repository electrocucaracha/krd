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
set -o nounset
set -o pipefail


# usage() - Prints the usage of the program
function usage {
    cat <<EOF
usage: $0 [-a addons] [-p] [-v] [-w dir ]
Optional Argument:
    -a List of Kubernetes AddOns to be installed ( e.g. "ovn ovn-kubernetes virtlet")
    -p Installation of ONAP MultiCloud Kubernetes plugin
    -v Enable verbosity
    -w Working directory
    -t Running healthchecks
EOF
}

# _install_go() - Install GoLang package
function _install_go {
    if $(go version &>/dev/null); then
        return
    fi
    local version=1.10.2
    local tarball=go$version.linux-amd64.tar.gz

    wget https://dl.google.com/go/$tarball
    tar -C /usr/local -xzf $tarball
    rm $tarball

    export PATH=$PATH:/usr/local/go/bin
    sed -i "s|^PATH=.*|PATH=\"$PATH\"|" /etc/environment
    mkdir -p $HOME/go/bin
    curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
}

# _install_pip() - Install Python Package Manager
function _install_pip {
    if $(pip --version &>/dev/null); then
        return
    fi
    apt-get install -y python-dev
    curl -sL https://bootstrap.pypa.io/get-pip.py | python
    pip install --upgrade pip
}

# _install_ansible() - Install and Configure Ansible program
function _install_ansible {
    mkdir -p /etc/ansible/
    cat <<EOL > /etc/ansible/ansible.cfg
[defaults]
host_key_checking = false
EOL
    if $(ansible --version &>/dev/null); then
        return
    fi
    _install_pip
    pip install ansible
}

# install_k8si() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    local dest_folder=/opt
    local version=2.5.0
    local tarball=v$version.tar.gz

    apt-get install -y sshpass
    _install_ansible
    wget https://github.com/kubernetes-incubator/kubespray/archive/$tarball
    tar -C $dest_folder -xzf $tarball
    rm $tarball

    pushd $dest_folder/kubespray-$version
        pip install -r requirements.txt
        rm -f $krd_inventory_folder/group_vars/all.yml
        if [ $http_proxy ]; then
            echo "http_proxy: \"$http_proxy\"" >> $krd_inventory_folder/group_vars/all.yml
        fi
        if [ $https_proxy ]; then
            echo "https_proxy: \"$https_proxy\"" >> $krd_inventory_folder/group_vars/all.yml
        fi
        ansible-playbook $verbose -i $krd_inventory cluster.yml -b | tee $log_folder/setup-kubernetes.log
    popd

    # Configure environment
    mkdir -p $HOME/.kube
    mv $HOME/admin.conf $HOME/.kube/config
}

# install_addons() - Install Kubenertes AddOns
function install_addons {
    echo "Installing Kubernetes AddOns"
    apt-get install -y sshpass
    _install_ansible
    ansible-galaxy install -r $krd_folder/galaxy-requirements.yml

    for addon in $addons; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-${addon}.yml | tee $log_folder/setup-${addon}.log
        if [[ -n "${plugin_enabled+x}" ]]; then
            pushd $krd_tests
            bash ${addon}.sh
            popd
        fi
    done
}

# install_plugin() - Install ONAP Multicloud Kubernetes plugin
function install_plugin {
    echo "Installing multicloud/k8s plugin"
    _install_go

    go get github.com/shank7485/k8-plugin-multicloud/...
}

# _print_kubernetes_info() - Prints the login Kubernetes information
function _print_kubernetes_info {
    if $(kubectl version &>/dev/null); then
        return
    fi
    NIC=$(ip route get 8.8.8.8 | awk '{ print $5; exit }')
    IP_ADDRESS=$(ifconfig $NIC | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2)

    printf "Kubernetes Info\n===============\n" > $k8s_info_file
    echo "Dashboard URL: https://$IP_ADDRESS:$(kubectl get service -n kube-system |grep kubernetes-dashboard | awk '{print $5}' |awk -F "[:/]" '{print $1}')" >> $k8s_info_file
    echo "Admin user: kube" >> $k8s_info_file
    echo "Admin password: secret" >> $k8s_info_file
}

# Configuration values
addons="virtlet ovn ovn-kubernetes"
krd_folder="$(dirname "$0")"
verbose=""

while getopts "a:pvw:t" opt; do
    case $opt in
        a)
            addons="$OPTARG"
            ;;
        p)
            plugin_enabled="true"
            ;;
        v)
            verbose="-vvv"
            ;;
        w)
            krd_folder="$OPTARG"
            ;;
        t)
            testing_enabled="true"
            ;;
        ?)
            usage
            exit
            ;;
    esac
done
log_folder=/var/log/krd
krd_inventory_folder=$krd_folder/inventory
krd_inventory=$krd_inventory_folder/hosts.ini
krd_playbooks=$krd_folder/playbooks
krd_tests=$krd_folder/tests
k8s_info_file=$krd_folder/k8s_info.log

mkdir -p $log_folder

# Install dependencies
apt-get update
install_k8s
install_addons
if [[ -n "${plugin_enabled+x}" ]]; then
    install_plugin
fi
_print_kubernetes_info
