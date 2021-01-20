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
set -o nounset

source _commons.sh
if [[ "$KRD_DEBUG" == "true" ]]; then
    set -o xtrace
fi

# add_k8s_nodes() - Add Kubernetes worker, master or etcd nodes to the existing cluster
function add_k8s_nodes {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/scale.yml" "scale-kubernetes.log"
}

# upgrade_k8s() - Function that graceful upgrades the Kubernetes cluster
function upgrade_k8s {
    kube_version=$(_get_kube_version)
    pushd "$kubespray_folder"
    kubespray_version=$(git describe --tags)
    popd

    if _vercmp "${kube_version#*v}" '==' "${KRD_KUBE_VERSION#*v}"; then
        echo "The kubespray instance has been deployed using the $kube_version version"
        return
    fi

    if [ -n "${KRD_KUBESPRAY_VERSION+x}" ] && _vercmp "${kubespray_version#*v}" '<' "${KRD_KUBESPRAY_VERSION#*v}" ; then
        sed -i "s/^kubespray_version: .*\$/kubespray_version: $KRD_KUBESPRAY_VERSION/" "$krd_playbooks/krd-vars.yml"
        pushd "$kubespray_folder"
        git checkout master
        git pull origin master
        git checkout -b "$KRD_KUBESPRAY_VERSION" "$KRD_KUBESPRAY_VERSION"
        PIP_CMD="sudo -E $(command -v pip) install --no-cache-dir"
        $PIP_CMD -r ./requirements.txt
        popd
    fi
    sed -i "s/^kube_version: .*\$/kube_version: $KRD_KUBE_VERSION/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    _run_ansible_cmd "$kubespray_folder/upgrade-cluster.yml" "upgrade-cluster-kubernetes.log"

    sudo cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo chown "$USER" "$HOME/.kube/config"
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

# wait_for_pods() - Function that waits for the running state
function wait_for_pods {
    local namespace=$1
    local timeout=${2:-900}

    end=$(date +%s)
    end=$((end + timeout))
    PENDING=True
    READY=False
    JOBR=False

    printf "Waiting for %s's pods..." "$namespace"
    until [ $PENDING == "False" ] && [ $READY == "True" ] && [ $JOBR == "True" ]; do
        printf "."
        sleep 5
        kubectl get pods -n "$namespace" -o jsonpath="{.items[*].status.phase}" | grep Pending > /dev/null && PENDING="True" || PENDING="False"
        query='.items[]|select(.status.phase=="Running")'
        query="$query|.status.containerStatuses[].ready"

        kubectl get pods -n "$namespace" -o json | jq -r "$query" | grep false > /dev/null && READY="False" || READY="True"
        kubectl get jobs -n "$namespace" -o json | jq -r '.items[] | .spec.completions == .status.succeeded' | grep false > /dev/null && JOBR="False" || JOBR="True"
        if [ "$(date +%s)" -gt $end ] ; then
            printf "Containers failed to start after %s seconds\n" "$timeout"
            kubectl get pods -n "$namespace" -o wide
            echo
            if [ $PENDING == "True" ] ; then
                echo "Some pods are in pending state:"
                kubectl get pods --field-selector=status.phase=Pending -n "$namespace" -o wide
            fi
            [ $READY == "False" ] && echo "Some pods are not ready"
            [ $JOBR == "False" ] && echo "Some jobs have not succeeded"
            exit
        fi
    done
}
