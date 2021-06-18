#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
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

# uninstall_k8s() - Uninstall Kubernetes cluster
function uninstall_k8s {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/reset.yml --extra-vars \"reset_confirmation=yes\"" "destroy-kubernetes.log"
}

function _uninstall_helm {
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')
    local helm_chart_name="$1"

    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        if helm ls --all --tiller-namespace "$KRD_TILLER_NAMESPACE" | grep -q "$helm_chart_name"; then
            helm delete "$helm_chart_name" --purge --tiller-namespace "$KRD_TILLER_NAMESPACE"
        fi
    else
        if helm ls --all | grep -q "$helm_chart_name"; then
            helm delete "$helm_chart_name"
        fi
    fi
}

function _uninstall_krew_plugin {
    local plugin=$1

    # shellcheck disable=SC1091
    source /etc/profile.d/krew_path.sh
    if kubectl krew search "$plugin" | grep -q "${plugin}.*yes"; then
        kubectl krew uninstall "$plugin"
    fi
}

# uninstall_metrics_server() - Uninstall Metrics Server services
function uninstall_metrics_server {
    _uninstall_helm metrics-server
}

# uninstall_kong() - Uninstall Kong ingress services
function uninstall_kong {
    _uninstall_helm kong
}

# uninstall_haproxy() - Uninstall HAProxy ingress services
function uninstall_haproxy {
    _uninstall_helm haproxy
}

# uninstall_falco() - Uninstall Falco services
function uninstall_falco {
    _uninstall_helm falco
}

# uninstall_metallb() - Uninstall MetalLB services
function uninstall_metallb {
    _delete_namespace metallb-system
}

# uninstall_istio() - Uninstall Istio services
function uninstall_istio {
    istioctl manifest generate | kubectl delete --ignore-not-found=true -f -
    _delete_namespace istio-system
}

# uninstall_kubevirt() - Uninstall KubeVirt servcies
function uninstall_kubevirt {
    kubevirt_version=$(_get_version kubevirt)

    kubectl delete kubevirt kubevirt -n kubevirt
    kubectl delete -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-operator.yaml" --ignore-not-found --wait=false
    if kubectl api-resources | grep -q kubevirt; then
        kubectl delete -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-cr.yaml"
    fi

    _uninstall_krew_plugin virt
    _delete_namespace kubevirt
}
