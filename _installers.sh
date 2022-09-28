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
    envsubst \$kube_version <kubespray_images.tpl >/tmp/kubespray_images.txt
    while IFS= read -r image; do
        skopeo copy --dest-tls-verify=false "docker://$image" "docker://localhost:5000/${image#*/}"
    done </tmp/kubespray_images.txt
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
            sudo curl -sLo "/usr/bin/$binary" "https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/${binary}_${cfssl_version}_$(uname | awk '{print tolower($0)}')_$(get_cpu_arch)" >/dev/null
            sudo chmod +x "/usr/bin/$binary"
        fi
    done
    sudo mkdir -p "$cert_dir"
    sudo chown -R "$USER:" "$cert_dir"
    pushd "$cert_dir" >/dev/null
    cfssl gencert -initca - <<EOF | cfssljson -bare ca
{
    "CN": "cert-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF
    KUBE_EDITOR="sed -i \"s|tls.crt\: .*|tls.crt\: $(base64 <ca.pem -w 0)|g; s|tls.key\: .*|tls.key\: $(base64 <ca-key.pem -w 0)|g\"" kubectl edit secret/ca-key-pair -n cert-manager
    popd >/dev/null

}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    echo "Installing Kubernetes"

    _install_kubespray

    sudo mkdir -p /etc/ansible/
    sudo cp "$KRD_FOLDER/ansible.tpl" /etc/ansible/ansible.cfg
    sudo sed -i "s|strategy_plugins = .*|strategy_plugins = $(dirname "$(sudo find / -name mitogen_linear.py | head -n 1)")|g" /etc/ansible/ansible.cfg
    _run_ansible_cmd "$kubespray_folder/cluster.yml" "setup-kubernetes.log"

    # Configure kubectl
    for dest in "$HOME" /root; do
        sudo mkdir -p "$dest/.kube"
        kubeconfig="$krd_inventory_folder/artifacts/admin.conf"
        [ ! -f "$kubeconfig" ] && kubeconfig="/etc/kubernetes/admin.conf"
        [ -f "$kubeconfig" ] && sudo cp "$kubeconfig" "$dest/.kube/config"
    done
    sudo chown -R "$USER" "$HOME/.kube/"
    [ -f "$HOME/.kube/config" ] && chmod 600 "$HOME/.kube/config"

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
    sudo cp "$KRD_FOLDER/ansible.tpl" /etc/ansible/ansible.cfg
    sudo sed -i "s|strategy_plugins = .*|strategy_plugins = $(dirname "$(sudo find / -name mitogen_linear.py | head -n 1)")|g" /etc/ansible/ansible.cfg
    pip_cmd="sudo -E $(command -v pip) install"
    ansible_galaxy_cmd="sudo -E $(command -v ansible-galaxy) install"
    if [ "$KRD_ANSIBLE_DEBUG" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
        pip_cmd+=" --verbose"
    fi
    eval "${ansible_galaxy_cmd} -p /tmp/galaxy-roles -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        sudo apt remove -y python3-yaml
        ;;
    esac
    eval "${pip_cmd} openshift"

    for addon in ${KRD_ADDONS_LIST//,/ }; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        _run_ansible_cmd "$krd_playbooks/configure-${addon}.yml" "setup-${addon}.log"
        if [[ $KRD_ENABLE_TESTS == "true" ]]; then
            pushd "$KRD_FOLDER"/tests
            bash "${addon}".sh
            popd
        fi
    done
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
    if [[ $KRD_ENABLE_ISTIO_ADDONS == "true" ]]; then
        for addon in grafana prometheus; do
            echo "Installing $addon Istio AddOn"
            kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/${addon}.yaml"
        done

        # Kiali installation
        install_helm
        echo "Installing Kiali Istio AddOn"
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
    istioctl manifest generate >/tmp/generated-manifest.yaml
    istioctl verify-install -f /tmp/generated-manifest.yaml
}

# install_knative() - Function that installs Knative and its dependencies
function install_knative {
    # Install Knative Client
    if ! command -v kn >/dev/null; then
        curl -fsSL http://bit.ly/install_pkg | PKG=kn PKG_KN_VERSION="$(_get_version kn)" bash
    fi

    # Install the Serving component
    # Resources requests:
    #  - Serving 630m CPU + 420Mi
    # Resources limits:
    #  - Serving 3,800m CPU + 3,700Mi
    if [[ ${KRD_KNATIVE_SERVING_ENABLED} == "true" ]]; then
        knative_serving_version=$(_get_version knative_serving)
        if ! kubectl get namespaces/knative-serving --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create namespace knative-serving
        fi
        kubectl apply -f "https://github.com/knative/serving/releases/download/${knative_serving_version}/serving-crds.yaml"
        kubectl apply -f "https://github.com/knative/serving/releases/download/${knative_serving_version}/serving-core.yaml"
        case ${KRD_KNATIVE_SERVING_NET} in
        kourier)
            kourier_version=$(_get_version net_kourier)
            kubectl apply -f "https://github.com/knative/net-kourier/releases/download/${kourier_version}/kourier.yaml"
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
        if [[ ${KRD_KNATIVE_SERVING_CERT_MANAGER_ENABLED} == "true" ]]; then
            kubectl apply -f "https://github.com/knative/net-certmanager/releases/download/$(_get_version net_certmanager)/release.yaml"
        fi

        wait_for_pods knative-serving
    fi

    # Install the Eventing component
    # Resources requests:
    #  - Eventing 420m CPU + 420Mi
    # Resources limits:
    #  - Eventing 600m CPU + 600Mi
    if [[ ${KRD_KNATIVE_EVENTING_ENABLED} == "true" ]]; then
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
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 15))
    done
    wait_for_pods kubevirt
}

# install_virtink() - Installs Virtink solution
function install_virtink {
    virtink_version=$(_get_version virtink)

    kubectl apply -f "https://github.com/smartxworks/virtink/releases/download/$virtink_version/virtink.yaml"
    wait_for_pods virtink-system
}
