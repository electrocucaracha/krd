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
if [[ $KRD_DEBUG == "true" ]]; then
    set -o xtrace
fi

# uninstall_k8s() - Uninstall Kubernetes cluster
function uninstall_k8s {
    [ ! -d $kubespray_folder ] && _install_kubespray
    _run_ansible_cmd "$kubespray_folder/reset.yml --extra-vars \"reset_confirmation=yes\"" "destroy-kubernetes.log"

    if _vercmp "$(python -V | awk '{print $2}')" '<' "3.8"; then
        sudo -E "$(command -v pip)" uninstall -y -r "$kubespray_folder/requirements-2.11.txt"
    else
        sudo -E "$(command -v pip)" uninstall -y -r "$kubespray_folder/requirements.txt"
    fi
}

function _uninstall_helm {
    local helm_chart_name="$1"

    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        if helm ls --all --tiller-namespace "$KRD_TILLER_NAMESPACE" | grep -q "$helm_chart_name"; then
            helm delete "$helm_chart_name" --purge --tiller-namespace "$KRD_TILLER_NAMESPACE"
        fi
    else
        for namespace in $(helm ls -A -f "$helm_chart_name" --deployed | grep deployed | awk '{ print $2}'); do
            helm delete "$helm_chart_name" -n "$namespace"
            if [[ "$helm_chart_name-system" == "$namespace" ]]; then
                _delete_namespace "$namespace"
            fi
        done
    fi
}

function _uninstall_krew_plugin {
    local plugin=$1

    [ -d "${KREW_ROOT:-$HOME/.krew}/bin" ] && export PATH="$PATH:${KREW_ROOT:-$HOME/.krew}/bin"
    ! kubectl plugin list | grep -q krew && return
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

# uninstall_falco() - Uninstall Falco services
function uninstall_falco {
    _uninstall_helm falco
}

# uninstall_gatekeeper() - Uninstall Gatekeeper services
function uninstall_gatekeeper {
    _uninstall_helm gatekeeper
    _delete_namespace opa-system
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

# uninstall_knative() - Uninstall Knative services
function uninstall_knative {
    if [[ ${KRD_KNATIVE_SERVING_ENABLED} == "true" ]]; then
        _delete_namespace knative-serving
    fi
    if [[ ${KRD_KNATIVE_EVENTING_ENABLED} == "true" ]]; then
        _delete_namespace knative-eventing
    fi
    _delete_namespace kourier-system

    case ${KRD_KNATIVE_SERVING_NET} in
    istio)
        uninstall_istio
        ;;
    esac
}

# uninstall_kubevirt() - Uninstall KubeVirt servcies
function uninstall_kubevirt {
    kubevirt_version=$(_get_version kubevirt)
    containerized_data_importer_version=$(_get_version containerized_data_importer)

    kubectl delete kubevirt kubevirt -n kubevirt --ignore-not-found --wait=false || :
    kubectl delete -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-operator.yaml" --ignore-not-found --wait=false || :
    if kubectl api-resources | grep -q kubevirt; then
        kubectl delete -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-cr.yaml" --ignore-not-found --wait=false || :
    fi

    kubectl delete -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${containerized_data_importer_version}/cdi-operator.yaml" --ignore-not-found --wait=false || :
    kubectl delete -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${containerized_data_importer_version}/cdi-cr.yaml" --ignore-not-found --wait=false || :

    _uninstall_krew_plugin virt
    _delete_namespace kubevirt
    _delete_namespace cdi
}

# uninstall_virtink() - Uninstall Virtink servcies
function uninstall_virtink {
    virtink_version=$(_get_version virtink)

    kubectl delete -f "https://github.com/smartxworks/virtink/releases/download/$virtink_version/virtink.yaml"
    _delete_namespace virtink-system
}

# uninstall_rook() - Uninstall Rook services
function uninstall_rook {
    _uninstall_helm rook-ceph
    _delete_namespace rook-ceph
    kubectl delete storageclasses.storage.k8s.io rook-ceph-block --ignore-not-found
    class="$(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name | awk 'NR==1{print $1}')"
    if [[ -n $class ]]; then
        kubectl patch storageclass "$class" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# uninstall_harbor() - Uninstall Harbor services
function uninstall_harbor {
    _uninstall_helm harbor
}

# uninstall_velero() - Uninstall Velero services
function uninstall_velero {
    _uninstall_helm velero
}

# uninstall_kyverno() - Uninstall Kyverno services
function uninstall_kyverno {
    _uninstall_helm kyverno
}

# uninstall_kubewarden() - Uninstall Kubewarden services
function uninstall_kubewarden {
    _uninstall_helm kubewarden-controllera || :
    _uninstall_helm kubewarden-crds
    _delete_namespace kubewarden-system
}

# uninstall_longhorn() - Uninstall Longhorn services
function uninstall_longhorn {
    kubectl patch settings.longhorn.io -n longhorn-system deleting-confirmation-flag --type merge -p '{"value": "true"}'
    _uninstall_helm longhorn
    _delete_namespace longhorn-system
}

# uninstall_topolvm() - Uninstall TopoLVM services
function uninstall_topolvm {
    _uninstall_helm topolvm
}

# uninstall_fluent() - Uninstall Fluent services
function uninstall_fluent {
    _uninstall_helm fluent
}

# _uninstall_chart_k8sgpt-operator() - Uninstall K8Sgpt Operator
function _uninstall_chart_k8sgpt-operator {
    _uninstall_helm k8sgpt-operator
    _delete_namespace k8sgpt-operator-system
}

# uninstall_kagent() - Uninstall kagent service
function uninstall_kagent {
    _uninstall_helm kagent || :
    _uninstall_helm kagent-crds
    _delete_namespace kagent-system
}
