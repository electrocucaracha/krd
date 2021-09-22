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
    local cfssl_version=1.5.0

    _install_krew_plugin cert-manager
    if ! command -v cfssl; then
        sudo curl -sLo /usr/bin/cfssl "https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl_${cfssl_version}_$(uname | awk '{print tolower($0)}')_$(get_cpu_arch)" > /dev/null
        sudo chmod +x /usr/bin/cfssl
    fi
    if ! command -v cfssljson; then
        sudo curl -sLo /usr/bin/cfssljson "https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssljson_${cfssl_version}_$(uname | awk '{print tolower($0)}')_$(get_cpu_arch)" > /dev/null
        sudo chmod +x /usr/bin/cfssljson
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

# install_openstack() - Function that install OpenStack Controller services
function install_openstack {
    echo "Deploying openstack"
    local dest_folder=/opt

    KRD_HELM_VERSION=2 install_helm
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

# install_harbor() - Function that installs Harbor Cloud Native registry project
function install_harbor {
    install_helm

    if ! helm repo list | grep -e harbor; then
        helm repo add harbor https://helm.goharbor.io
    fi
    if ! helm ls -qA | grep -q harbor; then
        helm upgrade --install harbor harbor/harbor \
        --wait
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
        if [ "$KRD_CNF_CONFORMANCE_INSTALL_METHOD" == "source" ]; then
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

    KRD_HELM_VERSION=2 install_helm

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

# install_nsm() - Installs Network Service Mesh
function install_nsm {
    KRD_HELM_VERSION=2 install_helm

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
    if ! helm ls -qA | grep -q velero; then
        helm upgrade --install velero vmware-tanzu/velero \
        --wait
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
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep $((attempt_counter*15))
    done
    wait_for_pods kubevirt
}

# install_kubesphere() - Installs KubeSphere services
function install_kubesphere {
    kubesphere_version=$(_get_version kubesphere)

    kubectl apply -f "https://github.com/kubesphere/ks-installer/releases/download/$kubesphere_version/kubesphere-installer.yaml"
    kubectl rollout status deployment/ks-installer -n kubesphere-system --timeout=5m
    cat <<EOF | kubectl apply -f -
---
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    version: $kubesphere_version
spec:
  persistence:
    storageClass: ""        # If there is not a default StorageClass in your cluster, you need to specify an existing StorageClass here.
  authentication:
    jwtSecret: ""           # Keep the jwtSecret consistent with the host cluster. Retrive the jwtSecret by executing "kubectl -n kubesphere-system get cm kubesphere-config -o yaml | grep -v "apiVersion" | grep jwtSecret" on the host cluster.
  etcd:
    monitoring: false       # Whether to enable etcd monitoring dashboard installation. You have to create a secret for etcd before you enable it.
    endpointIps: localhost  # etcd cluster EndpointIps, it can be a bunch of IPs here.
    port: 2379              # etcd port
    tlsEnable: true
  common:
    mysqlVolumeSize: 20Gi # MySQL PVC size.
    minioVolumeSize: 20Gi # Minio PVC size.
    etcdVolumeSize: 20Gi  # etcd PVC size.
    openldapVolumeSize: 2Gi   # openldap PVC size.
    redisVolumSize: 2Gi # Redis PVC size.
    es:   # Storage backend for logging, events and auditing.
      # elasticsearchMasterReplicas: 1   # total number of master nodes, it's not allowed to use even number
      # elasticsearchDataReplicas: 1     # total number of data nodes.
      elasticsearchMasterVolumeSize: 4Gi   # Volume size of Elasticsearch master nodes.
      elasticsearchDataVolumeSize: 20Gi    # Volume size of Elasticsearch data nodes.
      logMaxAge: 7                     # Log retention time in built-in Elasticsearch, it is 7 days by default.
      elkPrefix: logstash              # The string making up index names. The index name will be formatted as ks-<elk_prefix>-log.
  console:
    enableMultiLogin: true  # enable/disable multiple sing on, it allows an account can be used by different users at the same time.
    port: 30880
  alerting:                # (CPU: 0.3 Core, Memory: 300 MiB) Whether to install KubeSphere alerting system. It enables Users to customize alerting policies to send messages to receivers in time with different time intervals and alerting levels to choose from.
    enabled: false
  auditing:                # Whether to install KubeSphere audit log system. It provides a security-relevant chronological set of records，recording the sequence of activities happened in platform, initiated by different tenants.
    enabled: false
  devops:                  # (CPU: 0.47 Core, Memory: 8.6 G) Whether to install KubeSphere DevOps System. It provides out-of-box CI/CD system based on Jenkins, and automated workflow tools including Source-to-Image & Binary-to-Image.
    enabled: $KRD_KUBESPHERE_DEVOPS_ENABLED
    jenkinsMemoryLim: 2Gi      # Jenkins memory limit.
    jenkinsMemoryReq: 1500Mi   # Jenkins memory request.
    jenkinsVolumeSize: 8Gi     # Jenkins volume size.
    jenkinsJavaOpts_Xms: 512m  # The following three fields are JVM parameters.
    jenkinsJavaOpts_Xmx: 512m
    jenkinsJavaOpts_MaxRAM: 2g
  events:                  # Whether to install KubeSphere events system. It provides a graphical web console for Kubernetes Events exporting, filtering and alerting in multi-tenant Kubernetes clusters.
    enabled: false
    ruler:
      enabled: true
      replicas: 2
  logging:                 # (CPU: 57 m, Memory: 2.76 G) Whether to install KubeSphere logging system. Flexible logging functions are provided for log query, collection and management in a unified console. Additional log collectors can be added, such as Elasticsearch, Kafka and Fluentd.
    enabled: false
    logsidecarReplicas: 2
  metrics_server:                    # (CPU: 56 m, Memory: 44.35 MiB) Whether to install metrics-server. IT enables HPA (Horizontal Pod Autoscaler).
    enabled: $KRD_KUBESPHERE_METRICS_SERVER_ENABLED
  monitoring:
    # prometheusReplicas: 1            # Prometheus replicas are responsible for monitoring different segments of data source and provide high availability as well.
    prometheusMemoryRequest: 400Mi   # Prometheus request memory.
    prometheusVolumeSize: 20Gi       # Prometheus PVC size.
    # alertmanagerReplicas: 1          # AlertManager Replicas.
  multicluster:
    clusterRole: none  # host | member | none  # You can install a solo cluster, or specify it as the role of host or member cluster.
  networkpolicy:       # Network policies allow network isolation within the same cluster, which means firewalls can be set up between certain instances (Pods).
    # Make sure that the CNI network plugin used by the cluster supports NetworkPolicy. There are a number of CNI network plugins that support NetworkPolicy, including Calico, Cilium, Kube-router, Romana and Weave Net.
    enabled: false
  notification:        # Email Notification support for the legacy alerting system, should be enabled/disabled together with the above alerting option.
    enabled: false
  openpitrix:          # (2 Core, 3.6 G) Whether to install KubeSphere Application Store. It provides an application store for Helm-based applications, and offer application lifecycle management.
    enabled: false
  servicemesh:         # (0.3 Core, 300 MiB) Whether to install KubeSphere Service Mesh (Istio-based). It provides fine-grained traffic management, observability and tracing, and offer visualization for traffic topology.
    enabled: $KRD_KUBESPHERE_SERVICEMESH_ENABLED
EOF
    for namespace in "" -controls -monitoring -devops; do
        if kubectl get "namespace/kubesphere$namespace-system" --no-headers -o custom-columns=name:.metadata.name; then
            for deployment in $(kubectl get deployments --no-headers -o custom-columns=name:.metadata.name -n "kubesphere$namespace-system"); do
                kubectl rollout status "deployment/$deployment" -n "kubesphere$namespace-system" --timeout=5m
            done
        fi
    done
    echo "Track deployment process with: "
    echo "  kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-install -o jsonpath='{.items[0].metadata.name}') -f"
    echo "KubeSphere web console: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30880/login"
    echo "KubeSphere 'admin' user with 'P@88w0rd' password"
}

# install_longhorn() - Installs Longhorn is a lightweight, reliable
# and easy-to-use distributed block storage system
function install_longhorn {
    kube_version=$(_get_kube_version)
    install_helm

    if ! helm repo list | grep -e longhorn; then
        helm repo add longhorn https://charts.longhorn.io
        helm repo update
    fi
    if ! helm ls --namespace longhorn-system | grep -q longhorn; then
        helm upgrade --install longhorn longhorn/longhorn \
        --timeout 600s \
        --create-namespace \
        --namespace longhorn-system
    fi
    for daemonset in $(kubectl get daemonset -n longhorn-system --no-headers -o custom-columns=name:.metadata.name); do
        echo "Waiting for $daemonset to successfully rolled out"
        if ! kubectl rollout status "daemonset/$daemonset" -n longhorn-system --timeout=5m > /dev/null; then
            echo "The $daemonset daemonset has not started properly"
            exit 1
        fi
    done
    for deployment in $(kubectl get deployment -n longhorn-system --no-headers -o custom-columns=name:.metadata.name); do
        echo "Waiting for $deployment to successfully rolled out"
        if ! kubectl rollout status "deployment/$deployment" -n longhorn-system --timeout=5m > /dev/null; then
            echo "The $deployment deployment has not started properly"
            exit 1
        fi
    done
    if _vercmp "${kube_version#*v}" '>=' "1.19"; then
        cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80
EOF
    else
        cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: longhorn-frontend
          servicePort: 80
EOF
    fi
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
