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

# install_helm() - Function that installs Helm Client
function install_helm {
    local helm_version=${KRD_HELM_VERSION}

    if ! command -v helm  || _vercmp "$(helm version | awk -F '"' '{print substr($2,2); exit}')" '<' "$helm_version"; then
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

# install_helm_chart() - Function that installs additional Official Helm Charts
function install_helm_chart {
    if [ -z "$KRD_HELM_CHART" ]; then
        return
    fi

    install_helm

    helm upgrade "${KRD_HELM_NAME:-$KRD_HELM_CHART}" \
    "stable/$KRD_HELM_CHART" --install --atomic \
    --tiller-namespace "$KRD_TILLER_NAMESPACE"
}

# install_rook() - Function that install Rook Ceph operator
function install_rook {
    install_helm

    if ! helm repo list | grep -e rook-release; then
        helm repo add rook-release https://charts.rook.io/release
    fi
    if ! helm ls -qA | grep -q rook-ceph; then
        kubectl label nodes --all role=storage --overwrite
        helm upgrade --install rook-ceph rook-release/rook-ceph \
        --namespace rook-ceph \
        --create-namespace \
        --wait \
        --set agent.nodeAffinity="role=storage"
        wait_for_pods rook-ceph

        for class in $(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name); do
            kubectl patch storageclass "$class" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
        done

        kubectl apply -f resources/storageclass.yaml
        kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# install_metrics_server() - Installs Metrics Server services
function install_metrics_server {
    KRD_HELM_VERSION=2 install_helm
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
            --set image.repository="rancher/metrics-server" \
            --wait \
            --set args[0]="--kubelet-insecure-tls" \
            --set args[1]="--kubelet-preferred-address-types=InternalIP" \
            --set args[2]="--v=2" --tiller-namespace "$KRD_TILLER_NAMESPACE"
        fi
    else
        if ! helm repo list | grep -q stable; then
            helm repo add stable https://charts.helm.sh/stable
            helm repo update
        fi
        helm upgrade --install metrics-server stable/metrics-server \
        --set image.repository="rancher/metrics-server" \
        --wait \
        --set args[0]="--kubelet-insecure-tls" \
        --set args[1]="--kubelet-preferred-address-types=InternalIP"
    fi

    if ! kubectl rollout status deployment/metrics-server --timeout=5m > /dev/null; then
        echo "The metrics server has not started properly"
        exit 1
    fi
    attempt_counter=0
    max_attempts=5
    until kubectl top node 2> /dev/null; do
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep $((attempt_counter*60))
    done
    attempt_counter=0
    until kubectl top pod 2> /dev/null; do
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep $((attempt_counter*60))
    done
}

# install_kong() - Install Kong ingress services
function install_kong {
    install_helm

    if ! helm repo list | grep -e kong; then
        helm repo add kong https://charts.konghq.com
    fi
    if ! helm ls | grep -e kong; then
        helm upgrade --install kong kong/kong --set proxy.type=NodePort
    fi

    kubectl rollout status deployment/kong-kong --timeout=5m
}

# install_haproxy() - Install HAProxy ingress services
function install_haproxy {
    install_helm

    if ! helm repo list | grep -e haproxytech; then
        helm repo add haproxytech https://haproxytech.github.io/helm-charts
    fi
    if ! helm ls | grep -e haproxy; then
        helm upgrade --install haproxy haproxytech/kubernetes-ingress
    fi

    kubectl rollout status deployment/haproxy-kubernetes-ingress --timeout=5m
    kubectl rollout status deployment/haproxy-kubernetes-ingress-default-backend --timeout=5m
}

# install_falco() - Install Falco services
function install_falco {
    install_helm

    if ! helm repo list | grep -e falcosecurity; then
        helm repo add falcosecurity https://falcosecurity.github.io/charts
    fi
    if ! helm ls | grep -e falco; then
        helm upgrade -f helm/falco/custom-rules.yml \
        --set auditLog.enabled=true \
        --install falco falcosecurity/falco
    fi

    kubectl rollout status daemonset/falco --timeout=5m
}

# install_gatekeeper() - Install OPA Gatekeeper controller
function install_gatekeeper {
    install_helm

    if ! helm repo list | grep -e gatekeeper; then
        helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    fi
    if ! helm ls | grep -e gatekeeper; then
        helm upgrade --create-namespace \
        --namespace opa-system \
        --wait \
        --install gatekeeper gatekeeper/gatekeeper
    fi

    wait_for_pods opa-system
}

# install_kyverno() - Install Kyverno dynamic admission controller
function install_kyverno {
    install_gatekeeper
    install_helm

    if ! helm repo list | grep -e kyverno; then
        helm repo add kyverno https://kyverno.github.io/kyverno/
    fi
    if ! helm ls | grep -e kyverno-crds; then
        helm upgrade --create-namespace \
        --namespace kyverno-system \
        --wait \
        --install kyverno-crds kyverno/kyverno-crds
    fi
    if ! helm ls | grep -e kyverno; then
        helm upgrade --create-namespace \
        --namespace kyverno-system \
        --wait \
        --install kyverno kyverno/kyverno
    fi

    wait_for_pods kyverno-system
}
