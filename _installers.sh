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

export krd_inventory_folder=$KRD_FOLDER/inventory
krd_inventory=$krd_inventory_folder/hosts.ini
krd_playbooks=$KRD_FOLDER/playbooks
k8s_info_file=$KRD_FOLDER/k8s_info.log
kubespray_folder=/opt/kubespray

# _install_pip() - Install Python Package Manager
function _install_pip {
    if ! pip --version &>/dev/null; then
        install_package python-dev
        curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
    else
        sudo -E pip install --upgrade pip
    fi
}

# _install_ansible() - Install and Configure Ansible program
function _install_ansible {
    sudo mkdir -p /etc/ansible/
    sudo cp "$KRD_FOLDER/ansible.cfg" /etc/ansible/ansible.cfg
    if ! ansible --version &>/dev/null; then
        _install_pip
        sudo -E pip install ansible
    fi
}

# _install_docker() - Download and install docker-engine
function _install_docker {
    if docker version &>/dev/null; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        clear-linux-os)
            sudo -E swupd bundle-add ansible
            sudo systemctl unmask docker.service
        ;;
        *)
            curl -fsSL https://get.docker.com/ | sh
        ;;
    esac

    sudo mkdir -p /etc/systemd/system/docker.service.d
    if [ -n "$HTTP_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
        echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf
        echo "Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/https-proxy.conf
    fi
    if [ -n "$NO_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf
        echo "Environment=\"NO_PROXY=$NO_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/no-proxy.conf
    fi
    sudo systemctl daemon-reload
    sudo usermod -aG docker "$USER"
    sudo systemctl restart docker
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Deploying kubernetes"
    version=$(grep "kubespray_version" "${krd_playbooks}/krd-vars.yml" | awk -F ': ' '{print $2}')

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            ubuntu|debian)
                install_package sshpass
            ;;
            rhel|centos|fedora)
                install_package git
            ;;
            clear-linux-os)
                sudo swupd bundle-add git
            ;;
        esac

        _install_docker
        _install_ansible

        sudo git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder -b "$version"
        sudo chown -R "$USER" $kubespray_folder
        sudo -E pip install -r $kubespray_folder/requirements.txt

        rm -f "$krd_inventory_folder/group_vars/all.yml" 2> /dev/null
        verbose=""
        if [[ "${KRD_DEBUG}" == "true" ]]; then
            echo "kube_log_level: 5" | tee "$krd_inventory_folder/group_vars/all.yml"
            verbose="-vvv"
        else
            echo "kube_log_level: 2" | tee "$krd_inventory_folder/group_vars/all.yml"
        fi
        echo "kubeadm_enabled: true" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        if [[ -n "${HTTP_PROXY}" ]]; then
            echo "http_proxy: \"$HTTP_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [[ -n "${HTTPS_PROXY}" ]]; then
            echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [[ -n "${NO_PROXY}" ]]; then
            echo "no_proxy: \"$NO_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
    fi

    sudo ansible-playbook "$verbose" -i "$krd_inventory" "$kubespray_folder/cluster.yml" --become | tee "setup-kubernetes.log"

    # Configure environment
    mkdir -p "$HOME/.kube"
    cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
}

# install_addons() - Install Kubenertes AddOns
function install_addons {
    echo "Installing Kubernetes AddOns"
    _install_ansible
    verbose=""
    if [[ "${KRD_DEBUG}" == "true" ]]; then
        verbose="-vvv"
    fi
    sudo ansible-galaxy install "$verbose" -r "$KRD_FOLDER/galaxy-requirements.yml" --ignore-errors

    for addon in ${KRD_ADDONS:-virtlet multus istio kured}; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        sudo -E ansible-playbook "$verbose" -i "$krd_inventory" "$krd_playbooks/configure-${addon}.yml" | sudo tee "setup-${addon}.log"
        if [[ "${KRD_ENABLE_TESTS}" == "true" ]]; then
            pushd "$KRD_FOLDER"/tests
            bash "${addon}".sh
            popd
        fi
    done
}

# install_rundeck() - This function deploy a Rundeck instance
function install_rundeck {
    if rd version &>/dev/null; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            echo "deb https://rundeck.bintray.com/rundeck-deb /" | sudo tee -a /etc/apt/sources.list.d/rundeck.list
            curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -
            update_repos
            install_packages rundeck-cli rundeck
        ;;
        rhel|centos|fedora)
        ;;
    esac

    sudo chown -R rundeck:rundeck /var/lib/rundeck/

    sudo service rundeckd start
    sleep 10
    while ! grep -q "Grails application running at" /var/log/rundeck/service.log; do
        sleep 5
    done
    sudo mkdir -p /home/rundeck/.ssh
    sudo cp "$HOME"/.ssh/id_rsa /home/rundeck/.ssh
    sudo chown -R rundeck:rundeck /home/rundeck/

    export RD_URL=http://localhost:4440
    export RD_USER=admin
    export RD_PASSWORD=admin
    echo "export RD_URL=$RD_URL" | sudo tee --append /etc/environment
    echo "export RD_USER=$RD_USER" | sudo tee --append /etc/environment
    echo "export RD_PASSWORD=$RD_PASSWORD" | sudo tee --append /etc/environment

    pushd "$KRD_FOLDER"/rundeck
    rd projects create --project krd --file krd.properties
    rd jobs load --project krd --file Deploy_Kubernetes.yaml --format yaml
    popd
}

# _install_helm() - Function that installs Helm Client
function _install_helm {
    local helm_version=v2.13.1
    local helm_tarball=helm-${helm_version}-linux-amd64.tar.gz

    if ! helm version &>/dev/null; then
        wget http://storage.googleapis.com/kubernetes-helm/$helm_tarball
        tar -zxvf $helm_tarball -C /tmp
        rm $helm_tarball
        sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm
    fi

    helm init
    helm repo update

    echo 'Starting helm local repo'
    helm repo rm local
    helm serve &
    until curl -sSL --connect-timeout 1 http://localhost:8879 > /dev/null; do
        echo 'Waiting for helm serve to start'
        sleep 2
    done
    helm repo add local http://localhost:8879/charts
}

# install_prometheus() - Function that installs Prometheus operator
function install_prometheus {
    kubectl create -f https://coreos.com/operators/prometheus/latest/prometheus-operator.yaml
    kubectl create -f https://coreos.com/operators/prometheus/latest/prometheus-k8s.yaml

    # Deploy exporters providing metrics on cluster nodes and Kubernetes business logic
    kubectl create -f https://coreos.com/operators/prometheus/latest/exporters.yaml

    # Create the ConfigMap containing the Prometheus configuration
    kubectl apply -f https://coreos.com/operators/prometheus/latest/prometheus-k8s-cm.yaml
}

# install_helm_charts() - Function that installs additional Official Helm Charts
function install_helm_charts {
    _install_helm

    for chart in "kured";do
        helm install stable/$chart
    done
}

# install_openstack() - Function that install OpenStack Controller services
function install_openstack {
    echo "Deploying openstack"
    local dest_folder=/opt

    _install_helm
    _install_docker

    for repo in openstack-helm openstack-helm-infra; do
        sudo -E git clone https://git.openstack.org/openstack/$repo $dest_folder/$repo
    done
    sudo -H chown -R "$(id -un)": "$dest_folder/openstack-*"

    mkdir -p $dest_folder/openstack-helm-infra/tools/gate/devel/
    pushd $dest_folder/openstack-helm-infra/tools/gate/devel/
    git checkout c9396e348017822fc614296a1b9ec2852637bbbd # 2019-04-11
    echo "proxy:" | tee local-vars.yaml
    if [[ -n "${HTTP_PROXY}" ]]; then
        echo "  http: $HTTP_PROXY" | tee --append local-vars.yaml
    fi
    if [[ -n "${HTTPS_PROXY}" ]]; then
        echo "  https: $HTTPS_PROXY" | tee --append local-vars.yaml
    fi
    if [[ -n "${NO_PROXY}" ]]; then
        echo "  noproxy: $NO_PROXY,.svc.cluster.local" | tee --append local-vars.yaml
    fi
    popd
    pushd $dest_folder/openstack-helm
    git checkout 229db2f1552b2bfb0beece4ecd4a1b11eac690c0 # 2019-04-11
    for script in $(find ./tools/deployment/multinode -name "??0-*.sh" | sort); do
        $script | tee "${script%.*}.log"
    done
    popd
}
