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
    rm -rf "$kubespray_folder"
}

# uninstall_metrics_server() - Uninstall Metrics Server services
function uninstall_metrics_server {
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        if helm ls --all --tiller-namespace "$KRD_TILLER_NAMESPACE" | grep -q metrics-server; then
            helm delete metrics-server --purge --tiller-namespace "$KRD_TILLER_NAMESPACE"
        fi
    else
        if helm ls --all | grep -q metrics-server; then
            helm delete metrics-server
        fi
    fi
}
