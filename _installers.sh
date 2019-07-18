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

source _commons.sh

# _install_pip() - Install Python Package Manager
function _install_pip {
    if ! pip --version &>/dev/null; then
        _install_package python-dev
        curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
    else
        sudo -E pip install --upgrade pip
    fi
}

# _install_ansible() - Install and Configure Ansible program
function _install_ansible {
    sudo mkdir -p /etc/ansible/
    sudo cp "$KRD_FOLDER/ansible.cfg" /etc/ansible/ansible.cfg
    if ! ansible --version &>/dev/null; then
        _install_pip
        sudo -E pip install ansible
    fi
}

# _install_docker() - Download and install docker-engine
function _install_docker {
    if docker version &>/dev/null; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        clear-linux-os)
            sudo -E swupd bundle-add ansible
            sudo systemctl unmask docker.service
        ;;
        *)
            curl -fsSL https://get.docker.com/ | sh
        ;;
    esac

    sudo mkdir -p /etc/systemd/system/docker.service.d
    if [ -n "$HTTP_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
        echo "Environment=\"HTTP_PROXY=$HTTP_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
    fi
    if [ -n "$HTTPS_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf
        echo "Environment=\"HTTPS_PROXY=$HTTPS_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/https-proxy.conf
    fi
    if [ -n "$NO_PROXY" ]; then
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf
        echo "Environment=\"NO_PROXY=$NO_PROXY\"" | sudo tee --append /etc/systemd/system/docker.service.d/no-proxy.conf
    fi
    sudo systemctl daemon-reload
    sudo usermod -aG docker "$USER"
    sudo systemctl restart docker
}

# _install_kubespray() - Donwload Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"
        _install_package git
        sudo git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder -b "$kubespray_version"
        sudo chown -R "$USER" $kubespray_folder
        pushd $kubespray_folder
        sudo -E pip install -r ./requirements.txt
        make mitogen
        popd

        rm -f "$krd_inventory_folder/group_vars/all.yml" 2> /dev/null
        verbose=""
        if [[ "${KRD_DEBUG}" == "true" ]]; then
            echo "kube_log_level: 5" | tee "$krd_inventory_folder/group_vars/all.yml"
            verbose="-vvv"
        else
            echo "kube_log_level: 2" | tee "$krd_inventory_folder/group_vars/all.yml"
        fi
        echo "kubeadm_enabled: true" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        if [[ -n "${HTTP_PROXY}" ]]; then
            echo "http_proxy: \"$HTTP_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [[ -n "${HTTPS_PROXY}" ]]; then
            echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [[ -n "${NO_PROXY}" ]]; then
            echo "no_proxy: \"$NO_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
    fi
}

# install_k8s() - Install Kubernetes using kubespray tool
function install_k8s {
    _install_docker
    _install_ansible
    _install_kubespray

    echo "$ansible_cmd $kubespray_folder/cluster.yml"
    eval "$ansible_cmd $kubespray_folder/cluster.yml" | tee "setup-kubernetes.log"

    # Configure kubectl
    mkdir -p "$HOME/.kube"
    sudo cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo chown "$USER" "$HOME/.kube/config"
    sudo mv "$krd_inventory_folder/artifacts/kubectl" /usr/local/bin/kubectl
}

# install_addons() - Install Kubenertes AddOns
function install_addons {
    echo "Installing Kubernetes AddOns"
    _install_ansible
    ansible_galaxy_cmd="sudo ansible-galaxy install"
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
    fi
    eval "${ansible_galaxy_cmd} -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"

    for addon in ${KRD_ADDONS:-virtlet}; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        eval "$ansible_cmd $krd_playbooks/configure-${addon}.yml" | sudo tee "setup-${addon}.log"
        if [[ "${KRD_ENABLE_TESTS}" == "true" ]]; then
            pushd "$KRD_FOLDER"/tests
            bash "${addon}".sh
            popd
        fi
    done
}

# install_rundeck() - This function deploy a Rundeck instance
function install_rundeck {
    if rd version &>/dev/null; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            echo "deb https://rundeck.bintray.com/rundeck-deb /" | sudo tee -a /etc/apt/sources.list.d/rundeck.list
            curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -
            update_repos
        ;;
        rhel|centos|fedora)
        ;;
    esac
    _install_packages rundeck-cli rundeck

    sudo chown -R rundeck:rundeck /var/lib/rundeck/

    sudo service rundeckd start
    sleep 10
    while ! grep -q "Grails application running at" /var/log/rundeck/service.log; do
        sleep 5
    done
    sudo mkdir -p /home/rundeck/.ssh
    sudo cp "$HOME"/.ssh/id_rsa /home/rundeck/.ssh
    sudo chown -R rundeck:rundeck /home/rundeck/

    export RD_URL=http://localhost:4440
    export RD_USER=admin
    export RD_PASSWORD=admin
    echo "export RD_URL=$RD_URL" | sudo tee --append /etc/environment
    echo "export RD_USER=$RD_USER" | sudo tee --append /etc/environment
    echo "export RD_PASSWORD=$RD_PASSWORD" | sudo tee --append /etc/environment

    pushd "$KRD_FOLDER"/rundeck
    rd projects create --project krd --file krd.properties
    rd jobs load --project krd --file Deploy_Kubernetes.yaml --format yaml
    popd
}

# install_helm() - Function that installs Helm Client
function install_helm {
    if command -v helm; then
        return
    fi

    curl -L https://git.io/get_helm.sh | bash
    sudo useradd helm
    sudo sudo mkdir -p /home/helm/.kube
    sudo cp ~/.kube/config /home/helm/.kube/
    sudo chown helm -R /home/helm/
    sudo su helm -c "helm init --wait"

    sudo tee <<EOF /etc/systemd/system/helm-serve.service >/dev/null
[Unit]
Description=Helm Server
After=network.target

[Service]
User=helm
Restart=always
ExecStart=/usr/local/bin/helm serve

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl enable helm-serve
    sudo systemctl start helm-serve

    sudo su helm -c "helm repo remove local"
    sudo su helm -c "helm repo add local http://localhost:8879/charts"
    kubectl create serviceaccount --namespace kube-system tiller
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
    kubectl rollout status deployment/tiller-deploy --timeout=5m --namespace kube-system
    helm init --client-only
    helm repo update
}

# install_helm_chart() - Function that installs additional Official Helm Charts
function install_helm_chart {
    install_helm

    helm install "stable/$KRD_HELM_CHART"
}

# install_openstack() - Function that install OpenStack Controller services
function install_openstack {
    echo "Deploying openstack"
    local dest_folder=/opt

    install_helm

    kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
    for label in openstack-control-plane=enabled openstack-compute-node=enable openstack-helm-node-class=primary openvswitch=enabled linuxbridge=enabled; do
        kubectl label nodes "$label" --all
    done

    if [[ ! -d "$dest_folder/openstack-helm-infra" ]]; then
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm-infra "$dest_folder/openstack-helm-infra"
        sudo mkdir -p $dest_folder/openstack-helm-infra/tools/gate/devel/
        pushd $dest_folder/openstack-helm-infra/tools/gate/devel/
        sudo git checkout 9efb353b83c59e891b1b85dc6567044de0f5ac17 # 2019-05-28
        echo "proxy:" | sudo tee local-vars.yaml
        if [[ -n "${HTTP_PROXY}" ]]; then
            echo "  http: $HTTP_PROXY" | sudo tee --append local-vars.yaml
        fi
        if [[ -n "${HTTPS_PROXY}" ]]; then
            echo "  https: $HTTPS_PROXY" | sudo tee --append local-vars.yaml
        fi
        if [[ -n "${NO_PROXY}" ]]; then
            echo "  noproxy: $NO_PROXY,.svc.cluster.local" | sudo tee --append local-vars.yaml
        fi
        popd
        sudo -H chown -R helm: "$dest_folder/openstack-helm-infra"
        pushd $dest_folder/openstack-helm-infra/
        sudo su helm -c "make helm-toolkit"
        sudo su helm -c "helm repo index /home/helm/.helm/repository/local/"
        sudo su helm -c "make all"
        popd
    fi

    if [[ ! -d "$dest_folder/openstack-helm" ]]; then
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm-infra "$dest_folder/openstack-helm"
        pushd $dest_folder/openstack-helm
        sudo git checkout d334c5b68a082c0c09ce37116060b9efc1d45af4 # 2019-05-29
        sudo -H chown -R helm: "$dest_folder/openstack-helm"
        for script in $(find ./tools/deployment/multinode -name "??0-*.sh" | sort); do
            sudo su helm -c "$script" | tee "$HOME/${script%.*}.log"
        done
        popd
    fi
}

# install_istio() - Function that installs Istio
function install_istio {
    istio_version=$(_get_version istio)

    install_helm

    if command -v istioctl; then
        return
    fi

    curl -L https://git.io/getLatestIstio | ISTIO_VERSION="$istio_version" sh -
    pushd "./istio-$istio_version/bin"
    chmod +x ./istioctl
    sudo mv ./istioctl /usr/local/bin/istioctl
    popd
    rm -rf "./istio-$istio_version/"

    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/$istio_version/install/kubernetes/helm/helm-service-account.yaml"
    helm repo add istio.io "https://storage.googleapis.com/istio-release/releases/$istio_version/charts/"
    helm repo update
    if ! helm ls | grep -e istio-init; then
        helm install istio.io/istio-init --name istio-init --namespace istio-system
    fi
    echo "Waiting for istio-init to start..."
    until [[ $(kubectl get crds | grep -c 'istio.io\|certmanager.k8s.io') -ge "53" ]];do
        printf '.'
        sleep 2
    done
    if ! helm ls | grep -e "istio "; then
        helm install istio.io/istio --name istio --namespace istio-system --set global.configValidation=false
    fi
}

# install_knative() - Function taht installs Knative and its dependencies
function install_knative {
    knative_version=$(_get_version knative)

    install_istio

    kubectl apply --selector knative.dev/crd-install=true \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/serving.yaml" \
        --filename "https://github.com/knative/build/releases/download/v${knative_version}/build.yaml" \
        --filename "https://github.com/knative/eventing/releases/download/v${knative_version}/release.yaml" \
        --filename "https://github.com/knative/eventing-sources/releases/download/v${knative_version}/eventing-sources.yaml" \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/monitoring.yaml" \
        --filename "https://raw.githubusercontent.com/knative/serving/v${knative_version}/third_party/config/build/clusterrole.yaml"
    sleep 30
    kubectl apply --filename "https://github.com/knative/serving/releases/download/v${knative_version}/serving.yaml" --selector networking.knative.dev/certificate-provider!=cert-manager \
        --filename "https://github.com/knative/build/releases/download/v${knative_version}/build.yaml" \
        --filename "https://github.com/knative/eventing/releases/download/v${knative_version}/release.yaml" \
        --filename "https://github.com/knative/eventing-sources/releases/download/v${knative_version}/eventing-sources.yaml" \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/monitoring.yaml" \
        --filename "https://raw.githubusercontent.com/knative/serving/v${knative_version}/third_party/config/build/clusterrole.yaml"
}


# install_kiali() - Function that installs Kiali and its dependencies
function install_kiali {
    kiali_version=$(_get_version kiali)

    install_istio

    if kubectl get deployment --all-namespaces | grep kiali-operator; then
        return
    fi
    export AUTH_STRATEGY=anonymous
    export KIALI_IMAGE_VERSION=$kiali_version
    export ISTIO_NAMESPACE=istio-system

    bash <(curl -L https://git.io/getLatestKialiOperator)
}

# install_harbor() - Function that installs Harbor Cloud Native registry project
function install_harbor {
    install_helm

    helm repo add harbor https://helm.goharbor.io
    helm repo update

    helm install --name harbor harbor/harbor
}
