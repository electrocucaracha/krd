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

source _installers.sh

# uninstall_k8s() - Uninstall Kubernetes cluster
function uninstall_k8s {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/reset.yml" "destroy-kubernetes.log"
}

# add_k8s_nodes() - Add Kubernetes worker, master or etcd nodes to the existing cluster
function add_k8s_nodes {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/scale.yml" "scale-kubernetes.log"
}

# upgrade_k8s() - Function that graceful upgrades the Kubernetes cluster
function upgrade_k8s {
    kube_version=$(kubectl version --short | grep -e "Server" | awk -F ': ' '{print $2}')
    kubespray_version=$(_get_version kubespray)

    if _vercmp "${kube_version#*v}" '==' "${KRD_KUBE_VERSION#*v}"; then
        echo "The kubespray instance has been deployed using the $kube_version version"
        return
    fi

    if [ -n "${KRD_KUBESPRAY_VERSION+x}" ] && _vercmp "${kubespray_version#*v}" '<' "${KRD_KUBESPRAY_VERSION#*v}" ; then
        sed -i "s/^kubespray_version: .*\$/kubespray_version: $KRD_KUBESPRAY_VERSION/" "$krd_playbooks/krd-vars.yml"
        sudo rm -rf $kubespray_folder
        _install_kubespray
    fi
    sed -i "s/^kube_version: .*\$/kube_version: $KRD_KUBE_VERSION/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    _run_ansible_cmd "$kubespray_folder/upgrade-cluster.yml" "upgrade-cluster-kubernetes.log"

    sudo cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo chown "$USER" "$HOME/.kube/config"
    sudo mv "$krd_inventory_folder/artifacts/kubectl" /usr/local/bin/kubectl
}

# run_k8s_iperf() - Function that execute networking benchmark
function run_k8s_iperf {
    local ipef_folder=/opt/kubernetes-iperf3

    if [ ! -d "$ipef_folder" ]; then
        sudo git clone --depth 1 https://github.com/Pharb/kubernetes-iperf3.git "$ipef_folder"
        sudo chown -R "$USER" "$ipef_folder"
    fi
    pushd "$ipef_folder"
        ./iperf3.sh | tee ~/iperf3.log
    popd
}
