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

    sudo mkdir -p /etc/ansible/
    _configure_ansible
    _install_kubespray

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

function _ansible_galaxy_install {
    mkdir -p "$galaxy_base_path"
    ansible_galaxy_cmd="sudo -E $(command -v ansible-galaxy) $1 install"
    if [ "$KRD_ANSIBLE_DEBUG" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
        pip_cmd+=" --verbose"
    fi
    eval "${ansible_galaxy_cmd} -p $galaxy_base_path -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"
}

function _configure_ansible {
    sudo mkdir -p /etc/ansible/
    sudo tee /etc/ansible/ansible.cfg <<EOT
[ssh_connection]
pipelining=True
ansible_ssh_common_args = -o ControlMaster=auto -o ControlPersist=30m -o ConnectionAttempts=100
retries=2
[defaults]
forks = 20
strategy_plugins = $(dirname "$(sudo find / -name mitogen_linear.py | head -n 1)")

host_key_checking=False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_cache
stdout_callback = skippy
library = ./library:../library
callbacks_enabled = profile_tasks
jinja2_extensions = jinja2.ext.do
roles_path = $kubespray_folder/roles:$galaxy_base_path
EOT
}

# install_k8s_addons() - Install Kubenertes AddOns
function install_k8s_addons {
    echo "Installing Kubernetes AddOns"
    _configure_ansible
    _ansible_galaxy_install role
    _ansible_galaxy_install collection

    _run_ansible_cmd "$krd_playbooks/configure-addons.yml" "setup-addons.log" "$KRD_ADDONS_LIST"
}

# install_virtlet() - Install Virtlet
function install_virtlet {
    _configure_ansible
    _ansible_galaxy_install role
    _ansible_galaxy_install collection

    _run_ansible_cmd "$krd_playbooks/configure-virtlet.yml" "setup-virtlet.log"
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
    # TODO: Fix the following instruction to get targets information
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

    # CPU Allocation Ratio
    kubectl patch kubevirts.kubevirt.io -n kubevirt kubevirt --type merge -p "{\"spec\" :{\"configuration\": {\"developerConfiguration\": {\"cpuAllocationRatio\": ${KRD_KUBEVIRT_CPU_ALLOCATION_RATIO-5} }}}}"
    _install_containerized_data_importer
}

function _install_containerized_data_importer {
    containerized_data_importer_version=$(_get_version containerized_data_importer)

    kubectl apply -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${containerized_data_importer_version}/cdi-operator.yaml"
    kubectl apply -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${containerized_data_importer_version}/cdi-cr.yaml"

    wait_for_pods cdi
}

# install_virtink() - Installs Virtink solution
function install_virtink {
    virtink_version=$(_get_version virtink)

    kubectl apply -f "https://github.com/smartxworks/virtink/releases/download/$virtink_version/virtink.yaml"
    wait_for_pods virtink-system
}

# install_nephio() - Installs Nephio project
function install_nephio {
    pushd "$(mktemp -d -t "nephio-pkg-XXX")" >/dev/null || exit
    pkgs="nephio/core/porch "
    pkgs+="nephio/core/nephio-operator nephio/optional/resource-backend "
    pkgs+="nephio/core/configsync "         # Required for access tokens to connect to gitea services
    pkgs+="nephio/optional/network-config " # Required for workload cluster provisioning process

    for pkg in $pkgs; do
        _deploy_kpt_pkg "$pkg"
    done
    popd >/dev/null
    #kubectl prof -t 5m --lang go -n porch-system -o flamegraph --local-path=/tmp $(kubectl get pods -n porch-system -l app=porch-server -o jsonpath='{.items[*].metadata.name}')
}

# install_argocd() - Installs ArgoCD project
function install_argocd {
    argocd_version=$(_get_version argocd)

    kubectl create namespace argocd || :
    kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/$argocd_version/manifests/install.yaml"
    if [[ -n $(kubectl get ipaddresspools.metallb.io -n metallb-system -o jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}') ]]; then
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    fi
    wait_for_pods argocd

    admin_pass=$(kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
    _run_argocd_cmd login --username admin --password "$admin_pass"
    _run_argocd_cmd account update-password --account admin --current-password "$admin_pass" --new-password P4$$w0rd
    kubectl delete secrets -n argocd argocd-initial-admin-secret --ignore-not-found
}

# install_tekton() - Install Tekton project
function install_tekton {
    tekton_version=$(_get_version tekton)

    kubectl apply -f "https://infra.tekton.dev/tekton-releases/operator/previous/$tekton_version/release.yaml"
    wait_for_pods tekton-operator

    kubectl apply -f "https://raw.githubusercontent.com/tektoncd/operator/refs/tags/$tekton_version/config/crs/kubernetes/config/${KRD_TEKTON_OPERATOR_PROFILE-lite}/operator_v1alpha1_config_cr.yaml"
    wait_for_pods tekton-pipelines

    ! command -v tkn >/dev/null && curl -fsSL http://bit.ly/install_pkg | PKG=tkn bash
    kubectl get crds virtualmachines.kubevirt.io >/dev/null && kubectl apply -f "https://github.com/kubevirt/kubevirt-tekton-tasks/releases/download/$(_get_version kubevirt_tekton_tasks)/kubevirt-tekton-tasks.yaml"
}

# install_litellm() - Install LiteLLM server
function install_litellm {
    install_cnpg

    ! kubectl get namespaces litellm-system && kubectl create namespace litellm-system
    ! kubectl get secrets -n litellm-system litellm-secrets && kubectl create secret generic litellm-secrets -n litellm-system --from-literal=LITELLM_MASTER_KEY="$KRD_LITELLM_MASTER_KEY"
    kubectl apply -f "$KRD_FOLDER/resources/litellm.yml"
    wait_for_pods litellm-system
}

# install_external_snapshotter() Install CSI Snapshotter
function install_external_snapshotter {
    external_snapshotter_version=$(_get_version external_snapshotter)

    kubectl apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$external_snapshotter_version/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml"
    kubectl apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$external_snapshotter_version/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml"
    kubectl apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$external_snapshotter_version/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml"

    # Deploy snapshot controller
    kubectl apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$external_snapshotter_version/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml"
    kubectl apply -f "https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/$external_snapshotter_version/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml"
    kubectl rollout status deployment/snapshot-controller -n kube-system --timeout=5m
}
