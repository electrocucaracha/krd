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
if [[ $KRD_DEBUG == "true" ]]; then
    set -o xtrace
fi

# install_helm() - Function that installs Helm Client
function install_helm {
    local helm_version=${KRD_HELM_VERSION}

    if ! command -v helm || _vercmp "$(helm version | awk -F '"' '{print substr($2,2); exit}')" '<' "$helm_version"; then
        curl -fsSL http://bit.ly/install_pkg | PKG="helm" PKG_HELM_VERSION="$helm_version" bash
    fi

    # Configure Tiller for Helm v2
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')
    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        # Setup Tiller server
        if ! kubectl get "namespaces/$KRD_TILLER_NAMESPACE" --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create namespace "$KRD_TILLER_NAMESPACE"
        fi
        if ! kubectl get serviceaccount/tiller -n "$KRD_TILLER_NAMESPACE" --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create serviceaccount --namespace "$KRD_TILLER_NAMESPACE" tiller
        fi
        if ! kubectl get role/tiller-role -n "$KRD_TILLER_NAMESPACE" --no-headers -o custom-columns=name:.metadata.name; then
            cat <<EOF | kubectl apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-role
  namespace: $KRD_TILLER_NAMESPACE
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
EOF
        fi
        if ! kubectl get rolebinding/tiller-role-binding -n "$KRD_TILLER_NAMESPACE" --no-headers -o custom-columns=name:.metadata.name; then
            cat <<EOF | kubectl apply -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-role-binding
  namespace: $KRD_TILLER_NAMESPACE
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: $KRD_TILLER_NAMESPACE
roleRef:
  kind: Role
  name: tiller-role
  apiGroup: rbac.authorization.k8s.io
EOF
        fi
        sudo mkdir -p /home/helm/.kube/
        sudo cp ~/.kube/config /home/helm/.kube/
        sudo chown helm -R /home/helm/
        sudo su helm -c "helm init --wait --tiller-namespace $KRD_TILLER_NAMESPACE"
        kubectl patch deploy --namespace "$KRD_TILLER_NAMESPACE" tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
        kubectl rollout status deployment/tiller-deploy --timeout=5m --namespace "$KRD_TILLER_NAMESPACE"

        # Update repo info
        helm init --client-only
    fi
}

function _install_chart {
    local name="$1"
    local chart="$2"
    local namespace="${3:-"$name-system"}"

    install_helm
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '>=' '3' && ! helm ls | grep -e "$name"; then
        cmd="helm upgrade --create-namespace"
        cmd+=" --namespace $namespace --wait --install"
        echo "$cmd"
        if [ -n "${KRD_CHART_VALUES-}" ]; then
            for value in ${KRD_CHART_VALUES//,/ }; do
                cmd+=" --set $value"
            done
        fi
        if [ -n "${KRD_CHART_FILE-}" ]; then
            cmd+=" --values $KRD_CHART_FILE"
        fi
        eval "$cmd" "$name" "$chart"
    fi

    wait_for_pods "$namespace"
}

function _add_helm_repo {
    install_helm
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '>=' '3' && ! helm repo list | grep -e "$1"; then
        helm repo add "$1" "$2"
        helm repo update
    fi
}

# install_rook() - Function that install Rook Ceph operator
function install_rook {
    _add_helm_repo rook-release https://charts.rook.io/release
    kubectl label nodes --all role=storage --overwrite
    if ! helm ls -qA | grep -q rook-ceph; then
        KRD_CHART_VALUES="agent.nodeAffinity='role=storage'" _install_chart rook-ceph rook-release/rook-ceph rook-ceph

        for class in $(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name); do
            kubectl patch storageclass "$class" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        done

        kubectl apply -f resources/storageclass.yml
        kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# install_metrics_server() - Installs Metrics Server services
function install_metrics_server {
    install_helm
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        cat <<EOF | kubectl auth reconcile -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metrics-server-role
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings", "clusterroles", "rolebindings"]
  verbs: ["create", "delete", "bind"]
- apiGroups: ["apiregistration.k8s.io"]
  resources: ["apiservices"]
  verbs: ["create", "delete"]
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["extension-apiserver-authentication"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["namespaces", "nodes", "nodes/stats", "pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-server-tiller-binding
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: $KRD_TILLER_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metrics-server-role
EOF
        if ! helm ls --tiller-namespace "$KRD_TILLER_NAMESPACE" | grep -q metrics-server; then
            helm install stable/metrics-server --name metrics-server \
                --wait \
                --set args[0]="--kubelet-insecure-tls" \
                --set args[1]="--kubelet-preferred-address-types=InternalIP" \
                --set args[2]="--v=2" --tiller-namespace "$KRD_TILLER_NAMESPACE"
        fi
    else
        _add_helm_repo metrics-server https://kubernetes-sigs.github.io/metrics-server/
        KRD_CHART_VALUES="args[0]='--kubelet-insecure-tls',args[1]='--kubelet-preferred-address-types=InternalIP'" _install_chart metrics-server metrics-server/metrics-server default
    fi

    if ! kubectl rollout status deployment/metrics-server --timeout=5m >/dev/null; then
        echo "The metrics server has not started properly"
        exit 1
    fi
    attempt_counter=0
    max_attempts=5
    until kubectl top node 2>/dev/null; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 60))
    done
    attempt_counter=0
    until kubectl top pod 2>/dev/null; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 60))
    done
}

# install_kong() - Install Kong ingress services
function install_kong {
    _add_helm_repo kong https://charts.konghq.com
    KRD_CHART_VALUES="proxy.type=NodePort" _install_chart kong kong/kong default
}

# install_haproxy() - Install HAProxy ingress services
function install_haproxy {
    _add_helm_repo haproxytech https://haproxytech.github.io/helm-charts
    _install_chart haproxy haproxytech/kubernetes-ingress
}

# install_falco() - Install Falco services
function install_falco {
    _add_helm_repo falcosecurity https://falcosecurity.github.io/charts
    KRD_CHART_VALUES="auditLog.enabled=true" KRD_CHART_FILE="helm/falco/custom-rules.yml" _install_chart falco falcosecurity/falco
}

# install_gatekeeper() - Install OPA Gatekeeper controller
function install_gatekeeper {
    _add_helm_repo gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    _install_chart gatekeeper gatekeeper/gatekeeper opa-system
}

# install_kyverno() - Install Kyverno dynamic admission controller
function install_kyverno {
    install_gatekeeper
    _add_helm_repo kyverno https://kyverno.github.io/kyverno/
    _install_chart kyverno kyverno/kyverno
}

# install_kubewarden() - Install Kubewarden dynamic admission controller
function install_kubewarden {
    _add_helm_repo kubewarden https://charts.kubewarden.io
    _install_chart kubewarden-crds kubewarden/kubewarden-crds kubewarden-system
    _install_chart kubewarden-controller kubewarden/kubewarden-controller kubewarden-system
}

# install_kube-monkey() - Install Kube-Monkey chaos services
function install_kube-monkey {
    _add_helm_repo kubemonkey https://asobti.github.io/kube-monkey/charts/repo
    _install_chart kubemonkey kubemonkey/kube-monkey
}
