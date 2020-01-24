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

# _install_kubespray() - Donwload Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        pkgs=""
        for pkg in git make unzip ansible docker wget; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
        done
        if [ -n "$pkgs" ]; then
            curl -fsSL http://bit.ly/pkgInstall | PKG=$pkgs bash
        fi

        # TODO: Remove this condition when this change(https://github.com/kubernetes-sigs/kubespray/pull/5426#issuecomment-569326619) is included
        if [ -n "${KRD_CONTAINER_RUNTIME}" ] && [ "${KRD_CONTAINER_RUNTIME}" != "docker" ]; then
            sudo -E git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder
        else
            sudo -E git clone --depth 1 https://github.com/kubernetes-sigs/kubespray $kubespray_folder -b "$kubespray_version"
        fi
        sudo chown -R "$USER" $kubespray_folder
        pushd $kubespray_folder
        PIP_CMD="sudo -E $(command -v pip) install"
        $PIP_CMD -r ./requirements.txt
        make mitogen
        popd

        rm -rf "$krd_inventory_folder"/group_vars/
        mkdir -p "$krd_inventory_folder/group_vars/"
        cp "$KRD_FOLDER/k8s-cluster.yml" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        if [ "${KRD_DEBUG:-false}" == "true" ]; then
            echo "kube_log_level: 5" | tee "$krd_inventory_folder/group_vars/all.yml"
        else
            echo "kube_log_level: 2" | tee "$krd_inventory_folder/group_vars/all.yml"
        fi
        {
        echo "override_system_hostname: false"
        echo "kubeadm_enabled: true"
        echo "docker_dns_servers_strict: false"
        } >> "$krd_inventory_folder//group_vars/all.yml"
        if [ -n "${HTTP_PROXY}" ]; then
            echo "http_proxy: \"$HTTP_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [ -n "${HTTPS_PROXY}" ]; then
            echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        if [ -n "${NO_PROXY}" ]; then
            echo "no_proxy: \"$NO_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        fi
        # TODO: Remove this condition when this change(https://github.com/kubernetes-sigs/kubespray/issues/5472) is included
        if [ -n "${KRD_ENABLE_MULTUS}" ] && [ "${KRD_ENABLE_MULTUS}" == "true" ]; then
            sed -i 's/^kube_version: .*$/kube_version: v1.15.6/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        fi
        sed -i "s/^kube_network_plugin_multus: .*$/kube_network_plugin_multus: ${KRD_ENABLE_MULTUS:-false}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        if [ -n "${KRD_CONTAINER_RUNTIME}" ] && [ "${KRD_CONTAINER_RUNTIME}" != "docker" ]; then
            {
            echo "download_container: true"
            echo "skip_downloads: false"
            } >> "$krd_inventory_folder/group_vars/all.yml"
            sed -i 's/^download_run_once: .*$/download_run_once: false/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^download_localhost: .*$/download_localhost: false/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^kube_version: .*$/kube_version: v1.15.3/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^etcd_deployment_type: .*$/etcd_deployment_type: host/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^kubelet_deployment_type: .*$/kubelet_deployment_type: host/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i "s/^container_manager: .*$/container_manager: ${KRD_CONTAINER_RUNTIME}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        fi
        sed -i "s/^kube_network_plugin: .*$/kube_network_plugin: ${KRD_NETWORK_PLUGIN:-flannel}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
}

function _install_krew {
    local krew_version="v0.3.1"

    if kubectl krew version &>/dev/null; then
        return
    fi

    pushd "$(mktemp -d)"
    _install_package curl
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/${krew_version}/krew.{tar.gz,yaml}" &&
    tar zxvf krew.tar.gz
    ./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" install --manifest=krew.yaml --archive=krew.tar.gz
    export PATH="$PATH:${KREW_ROOT:-$HOME/.krew}/bin"
    sudo sed -i "s|^PATH=.*|PATH=\"$PATH\"|" /etc/environment
    kubectl krew update
    popd
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
    sudo mv "$krd_inventory_folder/artifacts/kubectl" /usr/local/bin/kubectl
    _install_krew
    kubectl krew install tree
}

# install_k8s_addons() - Install Kubenertes AddOns
function install_k8s_addons {
    echo "Installing Kubernetes AddOns"
    if ! command -v ansible; then
        curl -fsSL http://bit.ly/pkgInstall | PKG=ansible bash
    fi

    sudo mkdir -p /etc/ansible/
    sudo mkdir -p /tmp/galaxy-roles
    sudo cp "$KRD_FOLDER/ansible.cfg" /etc/ansible/ansible.cfg
    ansible_galaxy_cmd="sudo -E $(command -v ansible-galaxy) install"
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
    fi
    eval "${ansible_galaxy_cmd} -p /tmp/galaxy-roles -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"

    for addon in ${KRD_ADDONS:-addons}; do
        echo "Deploying $addon using configure-$addon.yml playbook.."
        _run_ansible_cmd "$krd_playbooks/configure-${addon}.yml" "setup-${addon}.log"
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
            _install_package curl
            curl 'https://bintray.com/user/downloadSubjectPublicKey?username=bintray' | sudo apt-key add -
            update_repos
        ;;
        rhel|centos|fedora)
            local java_version=1.8.0
            if ! command -v java; then
                _install_packages java-${java_version}-openjdk java-${java_version}-openjdk-devel
            fi
            sudo -E rpm -Uvh http://repo.rundeck.org/latest.rpm
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

    _install_package curl
    curl -L https://git.io/get_helm.sh | HELM_INSTALL_DIR=/usr/bin bash
    id -u helm &>/dev/null || sudo useradd helm
    echo "helm ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/helm
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
ExecStart=/usr/bin/helm serve

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
    pkgs=""
    for pkg in git make jq nmap curl bc; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/pkgInstall | PKG=$pkgs bash
    fi

    kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
    # TODO: Improve how the roles are assigned to the nodes
    for label in openstack-control-plane=enabled openstack-compute-node=enable openstack-helm-node-class=primary openvswitch=enabled linuxbridge=enabled ceph-mon=enabled ceph-mgr=enabled ceph-mds=enabled; do
        kubectl label nodes "$label" --all --overwrite
    done

    if [[ ! -d "$dest_folder/openstack-helm-infra" ]]; then
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm-infra "$dest_folder/openstack-helm-infra"
        sudo mkdir -p $dest_folder/openstack-helm-infra/tools/gate/devel/
        pushd $dest_folder/openstack-helm-infra/tools/gate/devel/
        sudo git checkout 70d93625e886a45c9afe2aa748228c39c5897e22 # 2020-01-21
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
        sudo -E git clone https://git.openstack.org/openstack/openstack-helm "$dest_folder/openstack-helm"
        pushd $dest_folder/openstack-helm
        sudo git checkout 1258061410908f62c247b437fcb12d2e478ac42d # 2020-01-20
        sudo -H chown -R helm: "$dest_folder/openstack-helm"
        for script in $(find ./tools/deployment/multinode -name "??0-*.sh" | sort); do
            filename=$(basename -- "$script")
            echo "Executing $filename ..."
            sudo su helm -c "$script" | tee "$HOME/${filename%.*}.log"
        done
        popd
    fi
}

# install_istio() - Function that installs Istio
function install_istio {
    istio_version=$(_get_version istio)

    if ! command -v istioctl; then
        _install_package curl
        curl -L https://git.io/getLatestIstio | ISTIO_VERSION="$istio_version" sh -
        chmod +x "./istio-$istio_version/bin/istioctl"
        sudo mv "./istio-$istio_version/bin/istioctl" /usr/local/bin/istioctl
        rm -rf "./istio-$istio_version/"
    fi

    install_helm
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/$istio_version/install/kubernetes/helm/helm-service-account.yaml"

    # Add helm chart release repositories
    if ! helm repo list | grep -e istio.io; then
        helm repo add istio.io "https://storage.googleapis.com/istio-release/releases/$istio_version/charts/"
        helm repo update
    fi

    # Install the istio-init chart to bootstrap all the Istio’s CRDs
    if ! helm ls | grep -e istio-init; then
        helm install istio.io/istio-init --name istio-init --namespace istio-system
    fi
    wait_for_pods istio-system

    if ! helm ls | grep -e "istio "; then
        helm install istio.io/istio --name istio --namespace istio-system
    fi
    wait_for_pods istio-system
}

# install_knative() - Function taht installs Knative and its dependencies
function install_knative {
    knative_version=$(_get_version knative)

    install_istio

    kubectl apply --selector knative.dev/crd-install=true \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/serving.yaml" \
        --filename "https://github.com/knative/eventing/releases/download/v${knative_version}/release.yaml" \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/monitoring.yaml"
    kubectl apply --filename "https://github.com/knative/serving/releases/download/v${knative_version}/serving.yaml" \
        --filename "https://github.com/knative/eventing/releases/download/v${knative_version}/release.yaml" \
        --filename "https://github.com/knative/serving/releases/download/v${knative_version}/monitoring.yaml"

    wait_for_pods knative-eventing
    wait_for_pods knative-monitoring
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

    _install_package curl
    bash <(curl -L https://git.io/getLatestKialiOperator)
}

# install_harbor() - Function that installs Harbor Cloud Native registry project
function install_harbor {
    install_helm

    if ! helm repo list | grep -e harbor; then
        helm repo add harbor https://helm.goharbor.io
    fi
    if ! helm ls | grep -e harbor; then
        helm install --name harbor harbor/harbor
    fi
}

# install_rook() - Function that install Rook Ceph operator
function install_rook {
    install_helm

    if ! helm repo list | grep -e rook-release; then
        helm repo add rook-release https://charts.rook.io/release
    fi
    if ! helm ls | grep -e rook-ceph; then
        kubectl label nodes --all role=storage --overwrite
        helm install --namespace rook-ceph --name rook-ceph rook-release/rook-ceph --wait --set csi.enableRbdDriver=false --set agent.nodeAffinity="role=storage"
        for file in common cluster-test toolbox; do
            kubectl apply -f "https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/$file.yaml"
        done

        printf "Waiting for Ceph cluster ..."
        until kubectl get pods -n rook-ceph | grep "csi-.*Running" > /dev/null; do
            printf "."
            sleep 2
        done

        touch ~/.bash_aliases
        if ! grep -q "alias ceph=" ~/.bash_aliases; then
            echo "alias ceph=\"kubectl -n rook-ceph exec -it \\\$(kubectl -n rook-ceph get pod -l 'app=rook-ceph-tools' -o jsonpath='{.items[0].metadata.name}') ceph\"" >> ~/.bash_aliases
        fi
        if ! grep -q "alias rados=" ~/.bash_aliases; then
            echo "alias rados=\"kubectl -n rook-ceph exec -it \\\$(kubectl -n rook-ceph get pod -l 'app=rook-ceph-tools' -o jsonpath='{.items[0].metadata.name}') rados\"" >> ~/.bash_aliases
        fi

        kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/flex/storageclass.yaml
        kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# install_octant() - Function that installs Octant which is a tool for developers to understand how applications run on a Kubernetes cluster
function install_octant {
    local version="0.5.1"
    local filename="octant_${version}_Linux-64bit"

    if command -v octant; then
        return
    fi

    _install_package wget
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
        wget "https://github.com/vmware/octant/releases/download/v$version/$filename.deb"
        sudo dpkg -i "$filename.deb"
        ;;
        rhel|centos|fedora)
        wget "https://github.com/vmware/octant/releases/download/v$version/$filename.rpm"
        sudo rpm -i "$filename.rpm"
        ;;
    esac
    rm "$filename".*
}

# install_kubelive() - Function that installs Kubelive tool
function install_kubelive {
    if command -v kubelive; then
        return
    fi

    if ! command -v npm; then
        _install_package curl
        curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
        _install_package nodejs

        # Update NPM to latest version
        npm config set registry http://registry.npmjs.org/
        if [[ ${HTTP_PROXY+x} = "x"  ]]; then
            npm config set proxy "$HTTP_PROXY"
        fi
        if [[ ${HTTPS_PROXY+x} = "x"  ]]; then
            npm config set https-proxy "$HTTPS_PROXY"
        fi
        sudo npm install -g npm
    fi

    sudo npm install -g kubelive
}

function install_cockpit {
    if systemctl is-active --quiet cockpit; then
        return
    fi

    _install_package cockpit
    if command -v firewall-cmd && systemctl is-active --quiet firewalld; then
        sudo firewall-cmd --permanent --add-service="cockpit" --zone=trusted
        sudo firewall-cmd --set-default-zone=trusted
        sudo firewall-cmd --reload
    fi
    sudo systemctl start cockpit
    sudo systemctl enable cockpit
}
