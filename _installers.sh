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

tiller_namespace=${KRD_TILLER_NAMESPACE:-default}

# _install_kubespray() - Donwload Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)

    # NOTE: bindep prints a multiline's output
    # shellcheck disable=SC2005
    pkgs="$(echo "$(bindep kubespray -b)")"
    for pkg in ansible docker kubectl; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        sudo -E git clone "https://github.com/kubernetes-sigs/kubespray" "$kubespray_folder"
        sudo chown -R "$USER:$USER" $kubespray_folder
        pushd $kubespray_folder
        if [ "$kubespray_version" != "master" ]; then
            git checkout -b "$kubespray_version" "$kubespray_version"
        fi
        PIP_CMD="sudo -E $(command -v pip) install --no-cache-dir"
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
        sed -i "s/^kube_network_plugin_multus: .*$/kube_network_plugin_multus: ${KRD_ENABLE_MULTUS:-false}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        if [ -n "${KRD_KUBE_VERSION}" ]; then
            sed -i "s/^kube_version: .*$/kube_version: ${KRD_KUBE_VERSION}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        fi
        if [ -n "${KRD_CONTAINER_RUNTIME}" ] && [ "${KRD_CONTAINER_RUNTIME}" != "docker" ]; then
            {
            echo "download_container: true"
            echo "skip_downloads: false"
            } >> "$krd_inventory_folder/group_vars/all.yml"
            sed -i 's/^download_run_once: .*$/download_run_once: false/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^download_localhost: .*$/download_localhost: false/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^etcd_deployment_type: .*$/etcd_deployment_type: host/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i 's/^kubelet_deployment_type: .*$/kubelet_deployment_type: host/' "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            sed -i "s/^container_manager: .*$/container_manager: ${KRD_CONTAINER_RUNTIME}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        fi
        sed -i "s/^kube_network_plugin: .*$/kube_network_plugin: ${KRD_NETWORK_PLUGIN:-flannel}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
}

function _update_ngnix_ingress_ca {
    local cert_dir=/opt/cert-manager/certs

    # shellcheck disable=SC1091
    source /etc/profile.d/krew_path.sh
    if [ "$(kubectl krew search cert-manager | awk 'FNR==2{ print $NF}')" == "no" ]; then
        kubectl krew install cert-manager
    fi
    if ! command -v go || _vercmp "$(go version | awk '{sub("go", "", $3) ; print $3}')" '<' "1.12"; then
        curl -fsSL http://bit.ly/install_pkg | PKG=go-lang bash
        # shellcheck disable=SC1091
        source /etc/profile.d/path.sh
    fi
    go_get_cmd="GOPATH=/tmp/ go get -u"
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        go_get_cmd+=" -v"
    fi
    if ! command -v cfssl; then
        eval "$go_get_cmd github.com/cloudflare/cfssl/cmd/cfssl"
        sudo mv /tmp/bin/cfssl /usr/bin/
    fi
    if ! command -v cfssljson; then
        eval "$go_get_cmd  github.com/cloudflare/cfssl/cmd/cfssljson"
        sudo mv /tmp/bin/cfssljson /usr/bin/
    fi
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

    # Configure Kubernetes Dashboard
    KUBE_EDITOR="sed -i \"s|type\: ClusterIP|type\: NodePort|g; s|nodePort\: .*|nodePort\: ${KRD_KUBERNETES_DASHBOARD_PORT:-30080}|g\"" kubectl -n kube-system edit service kubernetes-dashboard

    # Update Nginx Ingress CA certificate and key values
    if kubectl get secret/ca-key-pair -n cert-manager --no-headers -o custom-columns=name:.metadata.name; then
        _update_ngnix_ingress_ca
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
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        ansible_galaxy_cmd+=" -vvv"
        pip_cmd+=" --verbose"
    fi
    eval "${ansible_galaxy_cmd} -p /tmp/galaxy-roles -r $KRD_FOLDER/galaxy-requirements.yml --ignore-errors"
    eval "${pip_cmd} openshift"

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
    local helm_version=${KRD_HELM_VERSION:-2}

    if ! command -v helm  || _vercmp "$(helm version | awk -F '"' '{print substr($2,2); exit}')" '<' "$helm_version"; then
        curl -fsSL http://bit.ly/install_pkg | PKG="helm" PKG_HELM_VERSION="$helm_version" bash
    fi
    if [ "$helm_version" == "2" ]; then
        # Setup Tiller server
        if ! kubectl get "namespaces/$tiller_namespace" --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create namespace "$tiller_namespace"
        fi
        if ! kubectl get serviceaccount/tiller -n "$tiller_namespace" --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create serviceaccount --namespace "$tiller_namespace" tiller
        fi
        if ! kubectl get role/tiller-role -n "$tiller_namespace" --no-headers -o custom-columns=name:.metadata.name; then
            cat <<EOF | kubectl apply -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-role
  namespace: $tiller_namespace
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
EOF
        fi
        if ! kubectl get rolebinding/tiller-role-binding -n "$tiller_namespace" --no-headers -o custom-columns=name:.metadata.name; then
            cat <<EOF | kubectl apply -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-role-binding
  namespace: $tiller_namespace
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: $tiller_namespace
roleRef:
  kind: Role
  name: tiller-role
  apiGroup: rbac.authorization.k8s.io
EOF
        fi
        sudo cp ~/.kube/config /home/helm/.kube/
        sudo chown helm -R /home/helm/
        sudo su helm -c "helm init --wait --tiller-namespace $tiller_namespace"
        kubectl patch deploy --namespace "$tiller_namespace" tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
        kubectl rollout status deployment/tiller-deploy --timeout=5m --namespace "$tiller_namespace"

        # Update repo info
        helm init --client-only
    fi
}

# install_helm_chart() - Function that installs additional Official Helm Charts
function install_helm_chart {
    if [ -z "${KRD_HELM_CHART}" ]; then
        return
    fi

    install_helm

    helm upgrade "${KRD_HELM_NAME:-$KRD_HELM_CHART}" \
    "stable/$KRD_HELM_CHART" --install --atomic --tiller-namespace "$tiller_namespace"
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
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
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
        curl -L https://git.io/getLatestIstio | ISTIO_VERSION="$istio_version" sh -
        chmod +x "./istio-$istio_version/bin/istioctl"
        sudo mv "./istio-$istio_version/bin/istioctl" /usr/local/bin/istioctl
        rm -rf "./istio-$istio_version/"
    fi

    # Create a secret for Kiali service
    if ! kubectl get namespaces/istio-system --no-headers -o custom-columns=name:.metadata.name; then
        kubectl create namespace istio-system
    fi
    if ! kubectl get secrets/kiali --no-headers -o custom-columns=name:.metadata.name -n istio-system; then
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: $(echo "admin" | base64)
  passphrase: $(echo "admin" | base64)
EOF
    fi

    istioctl install --skip-confirmation \
    --set values.kiali.enabled=true || :
    wait_for_pods istio-system
    istioctl manifest generate --set values.kiali.enabled=true > /tmp/generated-manifest.yaml
    istioctl verify-install -f /tmp/generated-manifest.yaml
}

# install_knative() - Function taht installs Knative and its dependencies
function install_knative {
    knative_version=$(_get_version knative)

    install_istio

    # Using Istio mTLS feature
    if ! kubectl get namespaces/knative-serving --no-headers -o custom-columns=name:.metadata.name; then
        kubectl create namespace knative-serving
    fi
    kubectl label namespace knative-serving istio-injection=enabled --overwrite
    cat <<EOF | kubectl apply -f -
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "knative-serving"
spec:
  mtls:
    mode: PERMISSIVE
EOF
    if kubectl get service cluster-local-gateway -n istio-system; then
        kubectl apply -f "https://raw.githubusercontent.com/knative/serving/v${knative_version}/third_party/istio-1.4.9/istio-knative-extras.yaml"
    fi

    # Install the Serving component
    kubectl apply -f "https://github.com/knative/serving/releases/download/v${knative_version}/serving-crds.yaml"
    kubectl apply -f "https://github.com/knative/serving/releases/download/v${knative_version}/serving-core.yaml"
    kubectl apply -f "https://github.com/knative/net-istio/releases/download/v${knative_version}/release.yaml"

    # Install the Eventing component
    kubectl apply -f "https://github.com/knative/eventing/releases/download/v${knative_version}/eventing-crds.yaml"
    kubectl apply -f "https://github.com/knative/eventing/releases/download/v${knative_version}/eventing-core.yaml"

    ## Install a default Channel
    kubectl apply -f "https://github.com/knative/eventing/releases/download/v${knative_version}/in-memory-channel.yaml"

    ## Install a Broker
    kubectl apply -f "https://github.com/knative/eventing/releases/download/v${knative_version}/mt-channel-broker.yaml"

    wait_for_pods knative-serving
    wait_for_pods knative-eventing
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
    rook_version=$(_get_version rook)
    install_helm

    if ! helm repo list | grep -e rook-release; then
        helm repo add rook-release https://charts.rook.io/release
    fi
    if ! helm ls | grep -e rook-ceph; then
        kubectl label nodes --all role=storage --overwrite
        helm install --namespace rook-ceph --name rook-ceph rook-release/rook-ceph --wait --set csi.enableRbdDriver=false --set agent.nodeAffinity="role=storage"
        for file in common cluster-test toolbox; do
            kubectl apply -f "https://raw.githubusercontent.com/rook/rook/$rook_version/cluster/examples/kubernetes/ceph/$file.yaml"
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

        kubectl apply -f "https://raw.githubusercontent.com/rook/rook/$rook_version/cluster/examples/kubernetes/ceph/flex/storageclass.yaml"
        kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi
}

# install_octant() - Function that installs Octant which is a tool for developers to understand how applications run on a Kubernetes cluster
function install_octant {
    octant_version=$(_get_version octant)
    local filename="octant_${octant_version}_Linux-64bit"

    if command -v octant; then
        return
    fi

    pushd "$(mktemp -d)"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            curl -Lo "$filename.deb" "https://github.com/vmware-tanzu/octant/releases/download/v$octant_version/$filename.deb"
            sudo dpkg -i "$filename.deb"
        ;;
        rhel|centos|fedora)
            curl -Lo "$filename.rpm" "https://github.com/vmware-tanzu/octant/releases/download/v$octant_version/$filename.rpm"
            sudo rpm -i "$filename.rpm"
        ;;
    esac
    rm "$filename".*
    popd
}

# install_kubelive() - Function that installs Kubelive tool
function install_kubelive {
    if command -v kubelive; then
        return
    fi

    if ! command -v npm; then
        curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
        _install_packages nodejs

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

# install_cockpit() - Function that installs Cockpit tool
function install_cockpit {
    if systemctl is-active --quiet cockpit; then
        return
    fi

    _install_packages cockpit
    if command -v firewall-cmd && systemctl is-active --quiet firewalld; then
        sudo firewall-cmd --permanent --add-service="cockpit" --zone=trusted
        sudo firewall-cmd --set-default-zone=trusted
        sudo firewall-cmd --reload
    fi
    sudo systemctl start cockpit
    sudo systemctl enable cockpit
}

# run_cnf_conformance - Installs and runs CNF Conformance binary
function run_cnf_conformance {
    local cnf_conformance_dir="/opt/cnf-conformance"
    local version="v0.6.0"

    KRD_HELM_VERSION=3
    install_helm

    if [ ! -d "$cnf_conformance_dir" ]; then
        sudo git clone --depth 1 https://github.com/cncf/cnf-conformance "$cnf_conformance_dir" -b "$version"
        pushd "$cnf_conformance_dir/cnfs"
        sudo git clone --depth 1 https://github.com/cncf/cnf-testbed/
        popd
        sudo chown -R "$USER" "$cnf_conformance_dir"
    fi

    # Install cnf_conformance binary
    pushd "$cnf_conformance_dir"
    if ! command -v cnf-conformance; then
        if [ "${KRD_CNF_CONFORMANCE_INSTALL_METHOD:-binary}" == "source" ]; then
            if ! command -v crystal; then
                curl -fsSL http://bit.ly/install_pkg | PKG="crystal-lang" bash
            fi
            shards install
            crystal build src/cnf-conformance.cr --release --static
        else
            curl -sL -o cnf-conformance "https://github.com/cncf/cnf-conformance/releases/download/${version}/cnf-conformance"
            chmod +x cnf-conformance
        fi
        sudo cp cnf-conformance /usr/local/bin/cnf-conformance
    fi

    cnf-conformance setup
    while IFS= read -r -d '' file; do
        cnf-conformance cnf_setup cnf-config="$file"
    done < <(find ./example-cnfs -name cnf-conformance.yml -print0)
    popd
}

# run_sonobuoy - Installs and runs Sonobuoy conformance tool
function run_sonobuoy {
    local sonobuoy_dir="/opt/sonobuoy"
    local version="0.18.3"

    if [ ! -d "$sonobuoy_dir" ]; then
        pushd "$(mktemp -d)" > /dev/null
        curl -L -o sonobuoy.tgz "https://github.com/vmware-tanzu/sonobuoy/releases/download/v$version/sonobuoy_${version}_linux_amd64.tar.gz"
        tar xzf sonobuoy.tgz
        sudo mv sonobuoy /usr/local/bin/
        popd
    fi
    sonobuoy run --wait
    sonobuoy results "$(sonobuoy retrieve)"
    sonobuoy delete --wait
}

# install_ovn_metrics_dashboard() - Enables a Grafana dashboard
function install_ovn_metrics_dashboard {
    kube_ovn_version=$(_get_version kube-ovn)
    prometheus_operator_version=$(_get_version prometheus-operator)

    install_helm

    if ! helm ls | grep -e metrics-dashboard; then
        helm install stable/grafana --name metrics-dashboard -f ./helm/kube-ovn/grafana.yml
    fi
    kubectl apply -f "https://raw.githubusercontent.com/coreos/prometheus-operator/${prometheus_operator_version}/bundle.yaml"
    if ! kubectl get namespaces 2>/dev/null | grep  monitoring; then
        kubectl create namespace monitoring
    fi
    for resource in cni-monitor controller-monitor pinger-monitor; do
        kubectl apply -f "https://raw.githubusercontent.com/alauda/kube-ovn/${kube_ovn_version}/dist/monitoring/${resource}.yaml"
    done
}

# install_metrics_server() - Installs Metrics Server services
function install_metrics_server {
    install_helm

    if ! helm ls --tiller-namespace "$tiller_namespace" | grep -e metrics-server; then
clusterroles

        helm install stable/metrics-server --name metrics-server \
        --set args[0]="--kubelet-insecure-tls" \
        --set args[1]="--kubelet-preferred-address-types=InternalIP" \
        --set args[2]="--v=2" --tiller-namespace "$tiller_namespace"
    fi
}

# install_nsm() - Installs Network Service Mesh
function install_nsm {
    install_helm

    # Add helm chart release repositories
    if ! helm repo list | grep -e nsm; then
        helm repo add nsm https://helm.nsm.dev/
        helm repo update
    fi

    # Install the nsm chart
    if ! helm ls | grep -e nsm; then
        helm install nsm/nsm --name nsm
    fi

    for daemonset in $(kubectl get daemonset | grep nsm | awk '{print $1}'); do
        echo "Waiting for $daemonset to successfully rolled out"
        if ! kubectl rollout status "daemonset/$daemonset" --timeout=5m > /dev/null; then
            echo "The $daemonset daemonset has not started properly"
            exit 1
        fi
    done
}

# install_velero() - Installs Velero solution
function install_velero {
    install_helm

    # Add helm chart release repositories
    if ! helm repo list | grep -e vmware-tanzu; then
        helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
        helm repo update
    fi

    # Install the nsm chart
    if ! helm ls | grep -e velero; then
        helm install vmware-tanzu/velero --name velero
    fi
}

# install_kubevirt() - Installs KubeVirt solution
function install_kubevirt {
    kubevirt_version=$(_get_version kubevirt)

    kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-operator.yaml"
    if ! grep 'svm\|vmx' /proc/cpuinfo && ! kubectl get configmap -n kubevirt kubevirt-config; then
        kubectl create configmap kubevirt-config -n kubevirt --from-literal debug.useEmulation=true
    fi
    kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${kubevirt_version}/kubevirt-cr.yaml"
    kubectl krew install virt
    for deployment in api controller operator; do
        if kubectl get "deployment/virt-$deployment" -n kubevirt --no-headers -o custom-columns=name:.metadata.name; then
            kubectl rollout status "deployment/virt-$deployment" -n kubevirt --timeout=5m
        fi
    done
}

