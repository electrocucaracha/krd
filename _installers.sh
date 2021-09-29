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

# install_local_registry() - Installs a Docker registry
function install_local_registry {
    kube_version=$(_get_kube_version)

    pkgs=""
    for pkg in docker skopeo; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        # NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    # Start local registry
    if [[ -z $(sudo docker ps -aqf "name=registry") ]]; then
        sudo mkdir -p /var/lib/registry
        sudo -E docker run -d --name registry --restart=always \
        -p "$KRD_DOCKER_LOCAL_REGISTRY_PORT":5000 --userns=host \
        -v /var/lib/registry:/var/lib/registry registry:2
    fi

    # Preload Kubespray images
    export kube_version
    envsubst \$kube_version < kubespray_images.tpl > /tmp/kubespray_images.txt
    while IFS= read -r image; do
        skopeo copy --dest-tls-verify=false "docker://$image" "docker://localhost:5000/${image#*/}"
    done < /tmp/kubespray_images.txt
}

function _install_krew_plugin {
    local plugin=$1

    # shellcheck disable=SC1091
    source /etc/profile.d/krew_path.sh
    if kubectl krew search "$plugin" | grep -q "${plugin}.*no"; then
        kubectl krew install "$plugin"
    fi
}

function _update_ngnix_ingress_ca {
    local cert_dir=/opt/cert-manager/certs
    cfssl_version=$(_get_version cfssl)

    _install_krew_plugin cert-manager
    for binary in cfssl cfssljson; do
        if ! command -v "$binary"; then
            sudo curl -sLo "/usr/bin/$binary" "https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/${binary}_${cfssl_version}_$(uname | awk '{print tolower($0)}')_$(get_cpu_arch)" > /dev/null
            sudo chmod +x "/usr/bin/$binary"
        fi
    done
    sudo mkdir -p "$cert_dir"
    sudo chown -R "$USER:" "$cert_dir"
    pushd "$cert_dir" > /dev/null
    <<EOF cfssl gencert -initca - | cfssljson -bare ca
{
    "CN": "cert-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF
    KUBE_EDITOR="sed -i \"s|tls.crt\: .*|tls.crt\: $(< ca.pem base64 -w 0)|g; s|tls.key\: .*|tls.key\: $(< ca-key.pem base64 -w 0)|g\"" kubectl edit secret/ca-key-pair -n cert-manager
    popd > /dev/null

}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Installing Kubernetes"

    _install_kubespray

    sudo mkdir -p /etc/ansible/
    sudo cp "$KRD_FOLDER/ansible.cfg" /etc/ansible/ansible.cfg
    _run_ansible_cmd "$kubespray_folder/cluster.yml" "setup-kubernetes.log"

    # Configure kubectl
    mkdir -p "$HOME/.kube"
    sudo cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo chown -R "$USER" "$HOME/.kube/"
    chmod 600 "$HOME/.kube/config"

    # Update Nginx Ingress CA certificate and key values
    if kubectl get secret/ca-key-pair -n cert-manager --no-headers -o custom-columns=name:.metadata.name; then
        _update_ngnix_ingress_ca
    fi

    # Define ingress classes supported by KRD
    kube_version=$(_get_kube_version)
    if _vercmp "${kube_version#*v}" '>=' "1.19"; then
        kubectl apply -f resources/ingress-class.yml
    elif _vercmp "${kube_version#*v}" '>=' "1.18"; then
        kubectl apply -f resources/ingress-class_v1beta1.yml
    fi

    # Configure Kubernetes Dashboard
    if kubectl get deployment/kubernetes-dashboard -n kube-system --no-headers -o custom-columns=name:.metadata.name; then
        if kubectl get daemonsets/ingress-nginx-controller -n ingress-nginx --no-headers -o custom-columns=name:.metadata.name; then
            # Create an ingress route for the dashboard
            kubectl apply -f resources/dashboard-ingress.yml
        else
            KUBE_EDITOR="sed -i \"s|type\: ClusterIP|type\: NodePort|g; s|nodePort\: .*|nodePort\: $KRD_DASHBOARD_PORT|g\"" kubectl -n kube-system edit service kubernetes-dashboard
        fi
    fi

    # Sets Local storage as default Storage class
    if kubectl get storageclass/local-storage --no-headers -o custom-columns=name:.metadata.name; then
        kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# install_k8s_addons() - Install Kubenertes AddOns
function install_k8s_addons {
    echo "Installing Kubernetes AddOns"
    pkgs=""
    for pkg in ansible pip; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    sudo mkdir -p /etc/ansible/
    sudo mkdir -p /tmp/galaxy-roles
    sudo cp "$KRD_FOLDER/ansible.cfg" /etc/ansible/ansible.cfg
    pip_cmd="sudo -E $(command -v pip) install"
    ansible_galaxy_cmd="sudo -E $(command -v ansible-galaxy) install"
    if [ "$KRD_ANSIBLE_DEBUG" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
        pip_cmd+=" --verbose"
    fi
    eval "${ansible_galaxy_cmd} -p /tmp/galaxy-roles -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"
    eval "${pip_cmd} openshift"

    for addon in ${KRD_ADDONS_LIST//,/ }; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        _run_ansible_cmd "$krd_playbooks/configure-${addon}.yml" "setup-${addon}.log"
        if [[ "$KRD_ENABLE_TESTS" == "true" ]]; then
            pushd "$KRD_FOLDER"/tests
            bash "${addon}".sh
            popd
        fi
    done
}

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

# install_istio() - Function that installs Istio
# Resources requests (600m CPU + 2,176Mi):
# Resources limits (2000m CPU + 1Gi):
function install_istio {
    istio_version=$(_get_version istio)

    if ! command -v istioctl; then
        curl -L https://git.io/getLatestIstio | ISTIO_VERSION="$istio_version" sh -
        chmod +x "./istio-$istio_version/bin/istioctl"
        sudo mv "./istio-$istio_version/bin/istioctl" /usr/local/bin/istioctl
        rm -rf "./istio-$istio_version/"
    fi

    istioctl install --skip-confirmation || :
    if [[ "$KRD_ENABLE_ISTIO_ADDONS" == "true" ]]; then
        for addon in grafana prometheus; do
            echo  "Installing $addon Istio AddOn"
            kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/${addon}.yaml"
        done

        # Kiali installation
        install_helm
        echo  "Installing Kiali Istio AddOn"
        if ! helm repo list | grep -e kiali; then
            helm repo add kiali https://kiali.org/helm-charts
        fi
        if ! helm ls -n istio-system | grep -e kiali-server; then
            helm install --namespace istio-system \
            --set auth.strategy="anonymous" \
            kiali-server kiali/kiali-server
        fi
    fi
    wait_for_pods istio-system
    istioctl manifest generate > /tmp/generated-manifest.yaml
    istioctl verify-install -f /tmp/generated-manifest.yaml
}

# install_knative() - Function that installs Knative and its dependencies
function install_knative {
    # Install Knative Client
    if ! command -v kn > /dev/null; then
        kn_version=$(_get_version kn)
        curl -fsSL http://bit.ly/install_pkg | PKG=kn PKG_KN_VERSION="${kn_version#*v}" bash
    fi

    # Install the Serving component
    # Resources requests:
    #  - Serving 630m CPU + 420Mi
    # Resources limits:
    #  - Serving 3,800m CPU + 3,700Mi
    if [[ "${KRD_KNATIVE_SERVING_ENABLED}" == "true" ]]; then
        knative_serving_version=$(_get_version knative_serving)
        if ! kubectl get namespaces/knative-serving --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create namespace knative-serving
        fi
        kubectl apply -f "https://github.com/knative/serving/releases/download/${knative_serving_version}/serving-crds.yaml"
        kubectl apply -f "https://github.com/knative/serving/releases/download/${knative_serving_version}/serving-core.yaml"
        case ${KRD_KNATIVE_SERVING_NET} in
            kourier)
                kubectl apply -f "https://github.com/knative/net-kourier/releases/download/$(_get_version net_kourier)/kourier.yaml"
                kubectl patch configmap/config-network -n knative-serving \
                --type merge --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
            ;;
            istio)
                install_istio
                # Using Istio mTLS feature
                if kubectl get service cluster-local-gateway -n istio-system; then
                    kubectl apply -f "https://raw.githubusercontent.com/knative-sandbox/net-istio/master/third_party/istio-stable/istio-knative-extras.yaml"
                fi
                kubectl apply -f "https://github.com/knative/net-istio/releases/download/$(_get_version net_istio)/release.yaml"
            ;;
        esac
        if [[ "${KRD_KNATIVE_SERVING_CERT_MANAGER_ENABLED}" == "true" ]]; then
            kubectl apply -f "https://github.com/knative/net-certmanager/releases/download/$(_get_version net_certmanager)/release.yaml"
        fi

        wait_for_pods knative-serving
    fi

    # Install the Eventing component
    # Resources requests:
    #  - Eventing 420m CPU + 420Mi
    # Resources limits:
    #  - Eventing 600m CPU + 600Mi
    if [[ "${KRD_KNATIVE_EVENTING_ENABLED}" == "true" ]]; then
        knative_eventing_version=$(_get_version knative_eventing)
        kubectl apply -f "https://github.com/knative/eventing/releases/download/${knative_eventing_version}/eventing-crds.yaml"
        kubectl apply -f "https://github.com/knative/eventing/releases/download/${knative_eventing_version}/eventing-core.yaml"

        ## Install a default Channel
        kubectl apply -f "https://github.com/knative/eventing/releases/download/${knative_eventing_version}/in-memory-channel.yaml"

        ## Install a Broker
        kubectl apply -f "https://github.com/knative/eventing/releases/download/${knative_eventing_version}/mt-channel-broker.yaml"

        wait_for_pods knative-eventing
    fi
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

# install_kubevirt() - Installs KubeVirt solution
function install_kubevirt {
    kubevirt_version=$(_get_version kubevirt)
    attempt_counter=0
    max_attempts=5

    kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-operator.yaml"
    if ! grep 'svm\|vmx' /proc/cpuinfo && ! kubectl get configmap -n kubevirt kubevirt-config; then
        kubectl create configmap kubevirt-config -n kubevirt --from-literal debug.useEmulation=true
    fi
    kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-cr.yaml"
    _install_krew_plugin virt

    echo "Wait for Kubevirt resources to be ready"
    kubectl rollout status deployment/virt-operator -n kubevirt --timeout=5m
    until kubectl logs -n kubevirt -l kubevirt.io=virt-operator | grep "All KubeVirt components ready"; do
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep $((attempt_counter*15))
    done
    wait_for_pods kubevirt
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
