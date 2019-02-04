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

source _commons.sh

# _install_pip() - Install Python Package Manager
function _install_pip {
    if $(pip --version &>/dev/null); then
        install_package python-dev
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

    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            install_packages software-properties-common linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates curl
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
            update_repos
            install_package docker-ce
        ;;
        rhel|centos|fedora)
        ;;
    esac

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
    if [[ -z $(groups | grep docker) ]]; then
        sudo usermod -aG docker $USER
        newgrp docker
    fi

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

    install_package sshpass
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
    for addon in ${KRD_ADDONS:-ovn-kubernetes istio}; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        ansible-playbook $verbose -i $krd_inventory $krd_playbooks/configure-${addon}.yml | sudo tee $log_folder/setup-${addon}.log
        if [[ "${testing_enabled}" == "true" ]]; then
            pushd $krd_tests
            bash ${addon}.sh
            popd
        fi
    done
}

# install_rundeck() - This function deploy a Rundeck instance
function install_rundeck {
    if $(rd version &>/dev/null); then
        return
    fi

    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            echo "deb https://rundeck.bintray.com/rundeck-deb /" | sudo tee -a /etc/apt/sources.list.d/rundeck.list
            curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -
            update_repos
            install_package rundeck-cli rundeck
        ;;
        rhel|centos|fedora)
        ;;
    esac

    sudo chown -R rundeck:rundeck /var/lib/rundeck/

    sudo service rundeckd start
    sleep 10
    while [[ -z $(grep -E "Grails application running at" /var/log/rundeck/service.log) ]]; do
        sleep 5
    done
    sudo mkdir -p /home/rundeck/.ssh
    sudo cp $HOME/.ssh/id_rsa /home/rundeck/.ssh
    sudo chown -R rundeck:rundeck /home/rundeck/

    export RD_URL=http://localhost:4440
    export RD_USER=admin
    export RD_PASSWORD=admin
    echo "export RD_URL=$RD_URL" | sudo tee --append /etc/environment
    echo "export RD_USER=$RD_USER" | sudo tee --append /etc/environment
    echo "export RD_PASSWORD=$RD_PASSWORD" | sudo tee --append /etc/environment

    pushd $krd_folder/rundeck
    rd projects create --project krd --file krd.properties
    rd jobs load --project krd --file Deploy_Kubernetes.yaml --format yaml
    popd
}

# _install_helm() - Function that installs Helm Client
function _install_helm {
    local helm_version=v2.8.2
    local helm_tarball=helm-${helm_version}-linux-amd64.tar.gz

    if $(helm version &>/dev/null); then
        return
    fi

    wget http://storage.googleapis.com/kubernetes-helm/$helm_tarball
    tar -zxvf $helm_tarball -C /tmp
    rm $helm_tarball
    sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm

    helm init
    helm repo update
}

function install_helm_charts {
    _install_helm

    for chart in prometheus kured;do
        helm install stable/$chart
    done
}
