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
    echo "$ansible_cmd $kubespray_folder/reset.yml"
    eval "$ansible_cmd $kubespray_folder/reset.yml" | tee "destroy-kubernetes.log"
}

# add_k8s_nodes() - Add Kubernetes worker, master or etcd nodes to the existing cluster
function add_k8s_nodes {
    _install_kubespray
    echo "$ansible_cmd $kubespray_folder/scale.yml"
    eval "$ansible_cmd $kubespray_folder/scale.yml" | tee "scale-kubernetes.log"
}

# upgrade_k8s() - Function that graceful upgrades the Kubernetes cluster
function upgrade_k8s {
    kube_version=$(kubectl version --short | grep -e "Server" | awk -F ': ' '{print $2}')
    kubespray_version=$(_get_version kubespray)

    if _vercmp "${kube_version#*v}" '==' "${KRD_KUBE_VERSION#*v}"; then
        echo "The kubespray instance has been deployed using the $kube_version version"
        return
    fi

    if "$KRD_KUBESPRAY_VERSION" && _vercmp "${kubespray_version#*v}" '<' "${KRD_KUBESPRAY_VERSION#*v}"; then
        sed -i "s/^kubespray_version: .*\$/kubespray_version: $kubespray_version/" "$krd_playbooks/krd-vars.yml"
        rm -rf $kubespray_folder
        _install_kubespray
    fi
    sed -i "s/^kube_version: .*\$/kube_version: $KRD_KUBE_VERSION/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    echo "$ansible_cmd $kubespray_folder/upgrade-cluster.yml"
    eval "$ansible_cmd $kubespray_folder/upgrade-cluster.yml" | tee "upgrade-cluster-kubernetes.log"

    cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo mv "$krd_inventory_folder/artifacts/kubectl" /usr/local/bin/kubectl
}
