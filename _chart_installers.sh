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
            # editorconfig-checker-disable
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
            # editorconfig-checker-enable
        fi
        if ! kubectl get rolebinding/tiller-role-binding -n "$KRD_TILLER_NAMESPACE" --no-headers -o custom-columns=name:.metadata.name; then
            # editorconfig-checker-disable
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
            # editorconfig-checker-enable
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
    local wait="${4:-"true"}"

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
        if [ -n "${KRD_CHART_VERSION-}" ]; then
            cmd+=" --version $KRD_CHART_VERSION"
        fi
        eval "$cmd" "$name" "$chart"
    fi

    [[ $wait != "true" ]] || wait_for_pods "$namespace"
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
    _install_krew_plugin rook-ceph
}

# install_metrics_server() - Installs Metrics Server services
function install_metrics_server {
    install_helm
    helm_installed_version=$(helm version --short --client | awk '{sub(/+.*/,X,$0);sub(/Client: /,X,$0);print}')

    if _vercmp "${helm_installed_version#*v}" '<' '3'; then
        # editorconfig-checker-disable
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
        # editorconfig-checker-enable
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

# _install_chart_haproxy() - Install HAProxy ingress services
function _install_chart_haproxy {
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

# _install_chart_kube-monkey() - Install Kube-Monkey chaos services
function _install_chart_kube-monkey {
    _add_helm_repo kubemonkey https://asobti.github.io/kube-monkey/charts/repo
    _install_chart kubemonkey kubemonkey/kube-monkey
}

# _install_chart_local-ai() - Install LocalAI server
function _install_chart_local-ai {
    _add_helm_repo go-skynet https://go-skynet.github.io/helm-charts/
    KRD_CHART_FILE="helm/local-ai/values.yaml" _install_chart local-ai go-skynet/local-ai
}

# _install_chart_k8sgpt-operator() - Install K8sGPT operator
function _install_chart_k8sgpt-operator {
    _add_helm_repo k8sgpt https://charts.k8sgpt.ai/
    _install_chart k8sgpt-operator k8sgpt/k8sgpt-operator

    # Connect with LiteLLM
    if [ -n "${KRD_K8SGPT_OPENAI_TOKEN-}" ]; then
        kubectl create secret generic k8sgpt-sample-secret --from-literal=openai-api-key="$KRD_K8SGPT_OPENAI_TOKEN" -n k8sgpt-operator-system
        if kubectl get services -n litellm-system litellm-service >/dev/null; then
            kubectl apply -f resources/k8sgpt-openai_incluster.yml
        else
            kubectl apply -f resources/k8sgpt-openai.yml
        fi
        kubectl create clusterrolebinding k8sgpt-openai-role -n k8sgpt-operator-system --serviceaccount k8sgpt-operator-system:k8sgpt-k8sgpt-operator-system --clusterrole=k8sgpt-openai-role || :
    fi
}

function _install_arc_controller {
    KRD_CHART_VERSION=$(_get_version action_runner_controller) _install_chart arc oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
    kubectl apply -f resources/arc-cleanup.yml
}

# install_arc() - Install Actions Runner
function install_chart_arc {
    action_runner_controller_version=$(_get_version action_runner_controller)
    ! kubectl get crds autoscalinglisteners.actions.github.com >/dev/null && _install_arc_controller

    namespace="${KRD_ARC_GITHUB_URL##*/}"
    namespace="${namespace//_/-}"
    namespace="${namespace,,}"
    KRD_CHART_VALUES="githubConfigUrl=$KRD_ARC_GITHUB_URL,githubConfigSecret=gh-runners-token,maxRunners=3"
    ! kubectl get namespaces "${namespace}" && kubectl create namespace "${namespace}"
    ! kubectl get secrets -n "${namespace}" gh-runners-token && kubectl -n "${namespace}" create secret generic gh-runners-token --from-literal=github_token="$KRD_ARC_TOKEN"
    if kubectl get crds virtualmachines.kubevirt.io >/dev/null; then
        kubectl apply -f resources/kubevirt-runner/rbac.yml -n "$namespace"
        kubectl create rolebinding kubevirt-actions-runner -n "$namespace" --serviceaccount "${namespace}:kubevirt-actions-runner" --role=kubevirt-actions-runner || :
        kubectl create rolebinding "${namespace}-default-cdi-cloner" --serviceaccount "${namespace}:default" --clusterrole=cdi-cloner || :
        kubectl create rolebinding "${namespace}-kubevirt-actions-runner-cdi-cloner" --serviceaccount "${namespace}:kubevirt-actions-runner" --clusterrole=cdi-cloner || :
        kubectl apply -f resources/kubevirt-runner/vm.yml -n "$namespace"
        KRD_CHART_VERSION="$action_runner_controller_version" KRD_CHART_FILE="helm/arc/ubuntu-jammy-values.yml" _install_chart vm-self-hosted oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set "$namespace" "false"
    fi
}

# install_longhorn() - Installs Longhorn is a lightweight, reliable
# and easy-to-use distributed block storage system
function install_longhorn {
    _add_helm_repo longhorn https://charts.longhorn.io
    KRD_CHART_VALUES="defaultSettings.defaultDataPath=/var/lib/csi-block" _install_chart longhorn longhorn/longhorn
}

# install_topolvm() - Installs TopoLVM  distributed block storage system
function install_topolvm {
    _add_helm_repo topolvm https://topolvm.github.io/topolvm
    cert_manager_deployed="true"
    kubectl get deployments cert-manager -n cert-manager >/dev/null && cert_manager_deployed="false"
    replica_count=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | wc -l)
    for class in $(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name); do
        kubectl patch storageclass "$class" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
    done
    KRD_CHART_VALUES="lvmd.deviceClasses[0].name=ssd,lvmd.deviceClasses[0].default=true,lvmd.deviceClasses[0].spare-gb=10,lvmd.deviceClasses[0].volume-group=${KRD_TOPOLVM_VOLUME_GROUP_NAME-myvg1},cert-manager.enabled=$cert_manager_deployed,controller.replicaCount=$replica_count" _install_chart topolvm topolvm/topolvm
    kubectl patch storageclass topolvm-provisioner -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}

# install_fluent() - Installs Fluent for taking care of the log collection, parsing and distribution
function install_fluent {
    _add_helm_repo fluent https://fluent.github.io/helm-charts
    _install_chart fluent fluent/fluentd
}

# install_cnpg() - Installs CloudNativePG operator
function install_cnpg {
    _add_helm_repo cnpg https://cloudnative-pg.github.io/charts
    _install_chart cnpg cnpg/cloudnative-pg
}

# install_kagent() - Install kagent service
function install_kagent {
    command -v kagent >/dev/null || curl -s "https://i.jpillora.com/kagent-dev/kagent!!" | bash
    _install_chart kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds kagent-system false
    KRD_CHART_FILE="helm/kagent/without-agents.yml" KRD_CHART_VALUES="openai.apiKey=$KRD_KAGENT_OPENAI_TOKEN" _install_chart kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent
    kubectl apply -f resources/kagent/

    # TODO: Requires to pass the model info values (https://microsoft.github.io/autogen/stable/reference/python/autogen_ext.models.openai.html#autogen_ext.models.openai.OpenAIChatCompletionClient)
    # Connect with LiteLLM
    if [ -n "${KRD_KAGENT_OPENAI_TOKEN-}" ]; then
        if kubectl get services -n litellm-system litellm-service >/dev/null; then
            kubectl apply -f resources/kagent-openai-models_incluster.yml
        else
            kubectl apply -f resources/kagent-openai-models.yml
        fi
    fi
}
