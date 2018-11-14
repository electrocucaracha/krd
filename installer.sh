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
    -a List of Kubernetes AddOns to be installed ( e.g. "ovn-kubernetes virtlet multus")
    -v Enable verbosity
    -w Working directory
    -t Running healthchecks
EOF
}

# _install_pip() - Install Python Package Manager
function _install_pip {
    if $(pip --version &>/dev/null); then
        return
    fi
    apt-get install -y python-dev
    curl -sL https://bootstrap.pypa.io/get-pip.py | python
}

# _install_ansible() - Install and Configure Ansible program
function _install_ansible {
    mkdir -p /etc/ansible/
    cat <<EOL > /etc/ansible/ansible.cfg
[defaults]
host_key_checking = false
EOL
    if $(ansible --version &>/dev/null); then
        pip install --upgrade pip
    else
        _install_pip
    fi
    pip install ansible
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    local dest_folder=/opt
    version=$(grep "kubespray_version" ${krd_playbooks}/krd-vars.yml | awk -F ': ' '{print $2}')
    local tarball=v$version.tar.gz

    apt-get install -y sshpass
    _install_ansible
    wget https://github.com/kubernetes-incubator/kubespray/archive/$tarball
    tar -C $dest_folder -xzf $tarball
    rm $tarball

    pushd $dest_folder/kubespray-$version
        pip install -r requirements.txt
        rm -f $krd_inventory_folder/group_vars/all.yml 2> /dev/null
        if [[ -n "${verbose+x}" ]]; then
            echo "kube_log_level: 5" >> $krd_inventory_folder/group_vars/all.yml
        else
            echo "kube_log_level: 2" >> $krd_inventory_folder/group_vars/all.yml
        fi
        if [[ -n "${http_proxy+x}" ]]; then
            echo "http_proxy: \"$http_proxy\"" >> $krd_inventory_folder/group_vars/all.yml
        fi
        if [[ -n "${https_proxy+x}" ]]; then
            echo "https_proxy: \"$https_proxy\"" >> $krd_inventory_folder/group_vars/all.yml
        fi
        ansible-playbook $verbose -i $krd_inventory cluster.yml -b | tee $log_folder/setup-kubernetes.log
    popd

    # Configure environment
    mkdir -p $HOME/.kube
    mv $krd_inventory_folder/artifacts/admin.conf $HOME/.kube/config
}

# install_addons() - Install Kubenertes AddOns
function install_addons {
    echo "Installing Kubernetes AddOns"
    apt-get install -y sshpass
    _install_ansible
    ansible-galaxy install -r $krd_folder/galaxy-requirements.yml --ignore-errors

    ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-krd.yml | tee $log_folder/setup-krd.log
    for addon in $addons; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-${addon}.yml | tee $log_folder/setup-${addon}.log
        if [[ -n "${testing_enabled+x}" ]]; then
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

# Configuration values
addons="virtlet ovn-kubernetes multus nfd"
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
            set -o xtrace
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
# Setup proxy variables
if [ -f $krd_folder/sources.list ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.backup
    cp $krd_folder/sources.list /etc/apt/sources.list
fi
apt-get update
install_k8s
install_addons
_print_kubernetes_info
