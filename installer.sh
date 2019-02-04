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
source _installers.sh

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

update_repos
install_k8s
#install_addons
install_helm_charts
#install_rundeck
_print_kubernetes_info
