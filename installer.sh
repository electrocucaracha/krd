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
    -p Installation of ONAP MultiCloud Kubernetes plugin
    -v Enable verbosity
    -w Working directory
    -t Running healthchecks
EOF
}

# _install_go() - Install GoLang package
function _install_go {
    version=$(grep "go_version" ${krd_playbooks}/pinned_versions.yml | awk -F ': ' '{print $2}')
    local tarball=go$version.linux-amd64.tar.gz

    if $(go version &>/dev/null); then
        return
    fi

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

# _install_docker() - Download and install docker-engine
function _install_docker {
    local max_concurrent_downloads=${1:-3}

    if $(docker version &>/dev/null); then
        return
    fi
    apt-get install -y software-properties-common linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates curl
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce

    mkdir -p /etc/systemd/system/docker.service.d
    if [ $http_proxy ]; then
        cat <<EOL > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$http_proxy"
EOL
    fi
    if [ $https_proxy ]; then
        cat <<EOL > /etc/systemd/system/docker.service.d/https-proxy.conf
[Service]
Environment="HTTPS_PROXY=$https_proxy"
EOL
    fi
    if [ $no_proxy ]; then
        cat <<EOL > /etc/systemd/system/docker.service.d/no-proxy.conf
[Service]
Environment="NO_PROXY=$no_proxy"
EOL
    fi
    systemctl daemon-reload
    echo "DOCKER_OPTS=\"-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --max-concurrent-downloads $max_concurrent_downloads \"" >> /etc/default/docker
    usermod -aG docker $USER

    systemctl restart docker
    sleep 10
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    local dest_folder=/opt
    version=$(grep "kubespray_version" ${krd_playbooks}/pinned_versions.yml | awk -F ': ' '{print $2}')
    local tarball=v$version.tar.gz

    apt-get install -y sshpass
    _install_ansible
    wget https://github.com/kubernetes-incubator/kubespray/archive/$tarball
    tar -C $dest_folder -xzf $tarball
    rm $tarball

    pushd $dest_folder/kubespray-$version
        pip install -r requirements.txt
        rm -f $krd_inventory_folder/group_vars/all.yml
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
    mv $HOME/admin.conf $HOME/.kube/config
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

# install_plugin() - Install ONAP Multicloud Kubernetes plugin
function install_plugin {
    echo "Installing multicloud/k8s plugin"
    _install_go
    _install_docker
    pip install docker-compose

    mkdir -p /opt/{csar,kubeconfig,consul/config}
    cp $HOME/.kube/config /opt/kubeconfig/krd
    export CSAR_DIR=/opt/csar
    export KUBE_CONFIG_DIR=/opt/kubeconfig
    export DATABASE_TYPE=consul
    export DATABASE_IP=localhost
    echo "export CSAR_DIR=${CSAR_DIR}" >> /etc/environment
    echo "export KUBE_CONFIG_DIR=${KUBE_CONFIG_DIR}" >> /etc/environment
    echo "export DATABASE_TYPE=${DATABASE_TYPE}" >> /etc/environment
    echo "export DATABASE_IP=${DATABASE_IP}" >> /etc/environment

    go get github.com/shank7485/k8-plugin-multicloud/...
    export GOPATH=$HOME/go
    pushd $HOME/go/src/github.com/shank7485/k8-plugin-multicloud/deployments
    ./build.sh
    docker-compose up -d
    popd

    if [[ -n "${testing_enabled+x}" ]]; then
        pushd $krd_tests
        bash plugin.sh
        popd
    fi
}

# _install_crictl() - Install Container Runtime Interface (CRI) CLI
function _install_crictl {
    local version="v1.0.0-alpha.0" # More info: https://github.com/kubernetes-incubator/cri-tools#current-status

    wget https://github.com/kubernetes-incubator/cri-tools/releases/download/$version/crictl-$version-linux-amd64.tar.gz
    tar zxvf crictl-$version-linux-amd64.tar.gz -C /usr/local/bin
    rm -f crictl-$version-linux-amd64.tar.gz

    cat << EOL > /etc/crictl.yaml
runtime-endpoint: unix:///run/criproxy.sock
image-endpoint: unix:///run/criproxy.sock
EOL
}

# _print_kubernetes_info() - Prints the login Kubernetes information
function _print_kubernetes_info {
    if ! $(kubectl version &>/dev/null); then
        return
    fi
    # Expose Dashboard using NodePort
    KUBE_EDITOR="sed -i \"s|type\: ClusterIP|type\: NodePort|g\"" kubectl -n kube-system edit service kubernetes-dashboard

    master_ip=$(kubectl cluster-info | grep "Kubernetes master" | awk -F ":" '{print $2}')
    node_port=$(kubectl get service -n kube-system | grep kubernetes-dashboard | awk '{print $5}' |awk -F "[:/]" '{print $2}')

    printf "Kubernetes Info\n===============\n" > $k8s_info_file
    echo "Dashboard URL: https:$master_ip:$node_port" >> $k8s_info_file
    echo "Admin user: kube" >> $k8s_info_file
    echo "Admin password: secret" >> $k8s_info_file
}

# Configuration values
addons="virtlet ovn-kubernetes multus"
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
apt-get update
install_k8s
install_addons
if [[ -n "${plugin_enabled+x}" ]]; then
    install_plugin
fi
_print_kubernetes_info
