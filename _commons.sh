#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
#############################################################################

set -o errexit
set -o pipefail
set -o nounset
if [[ ${KRD_DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

source defaults.env

# Configuration values
KRD_FOLDER="$(git rev-parse --show-toplevel)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_playbooks=$KRD_FOLDER/playbooks
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray
export galaxy_base_path=/tmp/galaxy/

# _get_kube_version() - Get the Kubernetes version used or installed on the remote cluster
function _get_kube_version {
    if command -v kubectl >/dev/null && kubectl version >/dev/null 2>&1; then
        kubectl version -o yaml | grep gitVersion | awk 'FNR==2{ print $2}'
    elif [ -f "$KRD_FOLDER/k8s-cluster.yml" ]; then
        grep kube_version "$KRD_FOLDER/k8s-cluster.yml" | awk '{ print $2}'
    elif [ -n "${KRD_KUBE_VERSION-}" ]; then
        echo "${KRD_KUBE_VERSION}"
    else
        echo "v1.30.4"
    fi
}

# _install_kubespray() - Download Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)
    kube_version=$(_get_kube_version)
    mitogen_version=$(_get_version mitogen)

    curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="bindep" bash
    # NOTE: bindep prints a multiline's output
    # shellcheck disable=SC2005
    pkgs="$(echo "$(bindep kubespray -b)")"
    if [ "$KRD_DOWNLOAD_LOCALHOST" == "true" ] && ! command -v docker; then
        pkgs+=" docker"
    fi
    if ! command -v kubectl || ! kubectl krew version &>/dev/null; then
        PKG_KUBECTL_VERSION="${kube_version#*v}"
        export PKG_KUBECTL_VERSION
        pkgs+=" kubectl"
    fi
    if [ -n "$pkgs" ]; then
        # NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        sudo -E git clone "$KRD_KUBESPRAY_REPO" "$kubespray_folder"
        sudo chown -R "$USER:$USER" "$kubespray_folder"
        pushd "$kubespray_folder"
        if [ "$kubespray_version" != "master" ]; then
            git checkout -b "${kubespray_version#"origin/"}" "$kubespray_version"
        fi
        # TODO: Remove until this is merged (https://github.com/kubernetes-sigs/kubespray/pull/11434/commits/3036d7ef28b837ce7209a7cd72293fbce54a280c)
        curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kubespray/refs/heads/master/roles/kubernetes-apps/network_plugin/multus/tasks/main.yml" --output "roles/kubernetes-apps/network_plugin/multus/tasks/main.yml"

        curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="pip" bash
        PIP_CMD="sudo -E $(command -v pip)"
        if [[ "$(pip -V)" == *"python2"* ]] && command -v pip3; then
            PIP_CMD="sudo -E $(command -v pip3)"
        fi

        # This ensures that ansible is previously not installed
        if pip show ansible; then
            ansible_path="$(pip show ansible | grep Location | awk '{ print $2 }')/ansible"
            $PIP_CMD uninstall ansible -y
            sudo rm -rf "$ansible_path"
        fi
        if command -v pipx; then
            for pkg in ansible-base ansible-core; do
                if pipx list | grep -q "$pkg"; then
                    sudo -E "$(command -v pipx)" uninstall "$pkg"
                fi
            done
        fi

        python_version=$(python -V | awk '{print $2}')
        if _vercmp "$python_version" '<' "3.8"; then
            $PIP_CMD install --no-cache-dir -r ./requirements-2.11.txt
        else
            $PIP_CMD install --no-cache-dir -r ./requirements.txt
        fi
        if _vercmp "${kubespray_version#*v}" '<' "2.18"; then
            sed -i "s/mitogen_version: .*/mitogen_version: $mitogen_version/g" ./mitogen.yml
            sudo make mitogen
        else
            $PIP_CMD install --no-cache-dir mitogen
        fi
        popd
    fi

    mkdir -p "$krd_inventory_folder/group_vars/"
    cat <<EOF >"$krd_inventory_folder/group_vars/all.yml"
override_system_hostname: false
docker_dns_servers_strict: false
EOF
    if [ "$KRD_ANSIBLE_DEBUG" == "true" ]; then
        echo "kube_log_level: 5" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    else
        echo "kube_log_level: 2" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${HTTP_PROXY-}" ]; then
        echo "http_proxy: \"$HTTP_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${HTTPS_PROXY-}" ]; then
        echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${NO_PROXY-}" ]; then
        echo "no_proxy: \"$NO_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ "${KRD_METALLB_ENABLED-false}" == "true" ]; then
        echo 'metallb_namespace: "metallb-system"' | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE="docker"
    if [ "$KRD_CONTAINER_RUNTIME" != "docker" ]; then
        # https://github.com/kubernetes-sigs/kubespray/pull/6997
        # https://github.com/kubernetes-sigs/kubespray/pull/6998
        if [ "$kubespray_version" != "master" ] && _vercmp "${kubespray_version#*v}" '<' "2.15"; then
            export KRD_DOWNLOAD_RUN_ONCE=false
        fi
        echo "download_container: false" | tee --append "$krd_inventory_folder/group_vars/all.yml"
        KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE="host"
        if [ "$KRD_CONTAINER_RUNTIME" == "containerd" ]; then
            export KRD_CRUN_ENABLED=false
        fi
    elif _vercmp "${kube_version#*v}" '>=' "1.24"; then
        echo "Dockershim has been deprecated in <1.24"
        exit 1
    fi
    if [ "$KRD_NETWORK_PLUGIN" == "calico" ]; then
        if [ "$KRD_CALICO_IPIP_MODE" == "Never" ] && [ "$KRD_CALICO_VXLAN_MODE" == "Never" ]; then
            export KRD_CALICO_NETWORK_BACKEND=bird
        elif [ "$KRD_CALICO_IPIP_MODE" != "Never" ] && [ "$KRD_CALICO_VXLAN_MODE" != "Never" ]; then
            echo "Calico encapsulation mode was misconfigured"
            exit 1
        fi
    fi
    export KRD_DOWNLOAD_LOCALHOST=$KRD_DOWNLOAD_RUN_ONCE
    export KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE
    envsubst <k8s-cluster.tpl >"$krd_inventory_folder/group_vars/k8s-cluster.yml"
    if [ -n "${KRD_KUBE_VERSION-}" ]; then
        sed -i "s/^kube_version: .*$/kube_version: ${KRD_KUBE_VERSION}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
    if [ -n "${KRD_MANUAL_DNS_SERVER-}" ]; then
        sed -i "s/^manual_dns_server: .*$/manual_dns_server: $KRD_MANUAL_DNS_SERVER/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
    if [ -n "${KRD_REGISTRY_MIRRORS_LIST-}" ] && [ "$KRD_CONTAINER_RUNTIME" != "containerd" ]; then
        if [ "$KRD_CONTAINER_RUNTIME" == "docker" ]; then
            echo "docker_registry_mirrors:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            for mirror in ${KRD_REGISTRY_MIRRORS_LIST//,/ }; do
                echo "  - $mirror" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            done
        elif [ "$KRD_CONTAINER_RUNTIME" == "crio" ]; then
            echo "crio_registries:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            if _vercmp "${kubespray_version#*v}" '<' "2.18"; then
                for mirror in ${KRD_REGISTRY_MIRRORS_LIST//,/ }; do
                    echo "  - ${mirror#*//}" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                done
            else
                echo "  - location: registry-1.docker.io" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                echo "    unqualified: false" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                echo "    mirrors:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                for mirror in ${KRD_REGISTRY_MIRRORS_LIST//,/ }; do
                    echo "      - location: ${mirror#*//}" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                    if [[ ${mirror#*//} == *"$KRD_INSECURE_REGISTRIES_LIST"* ]]; then
                        echo "        insecure: true" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                    else
                        echo "        insecure: false" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
                    fi
                done
            fi
        fi
    fi
    if [ -n "${KRD_INSECURE_REGISTRIES_LIST-}" ] && [ "$KRD_CONTAINER_RUNTIME" != "containerd" ]; then
        if [ "$KRD_CONTAINER_RUNTIME" == "docker" ]; then
            echo "docker_insecure_registries:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            for registry in ${KRD_INSECURE_REGISTRIES_LIST//,/ }; do
                echo "  - $registry" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            done
        elif [ "$KRD_CONTAINER_RUNTIME" == "crio" ] && _vercmp "${kubespray_version#*v}" '<' "2.18"; then
            echo "crio_insecure_registries:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            for registry in ${KRD_INSECURE_REGISTRIES_LIST//,/ }; do
                echo "  - $registry" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            done
        fi
    fi
    if [ -n "${KRD_DNS_ETCHOSTS_DICT-}" ]; then
        echo "dns_etchosts: |" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        for etchost_entry in ${KRD_DNS_ETCHOSTS_DICT//,/ }; do
            echo "  ${etchost_entry%-*} ${etchost_entry#*-}" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        done
    fi
    if [ "$KRD_NETWORK_PLUGIN" == "cilium" ] && [ "$KRD_CILIUM_TUNNEL_MODE" == "disabled" ]; then
        echo "cilium_auto_direct_node_routes: true" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
    if [ "$kubespray_version" != "master" ] && _vercmp "${kubespray_version#*v}" '>' "2.15" && [ "$KRD_METALLB_ENABLED" == "true" ] && [ -n "${KRD_METALLB_ADDRESS_POOLS_LIST-}" ]; then
        echo "metallb_ip_range:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        for pool in ${KRD_METALLB_ADDRESS_POOLS_LIST//,/ }; do
            echo "  - $pool" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        done
    fi
}

# install_metallb() - Install MetalLB services
function install_metallb {
    metallb_version=$(_get_version metallb)

    if ! kubectl get namespaces/metallb-system --no-headers -o custom-columns=name:.metadata.name; then
        if _vercmp "${metallb_version#*v}" '<' "0.13"; then
            kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$metallb_version/manifests/namespace.yaml"
            kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$metallb_version/manifests/metallb.yaml"
        else
            kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$metallb_version/config/manifests/metallb-native.yaml"
        fi
        if ! kubectl get secret/memberlist -n metallb-system --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
        fi
    fi

    wait_for_pods metallb-system

    if [ -n "${KRD_METALLB_ADDRESS_POOLS_LIST-}" ]; then
        ranges=""
        for range in ${KRD_METALLB_ADDRESS_POOLS_LIST//,/ }; do
            ranges+="          - ${range}\n"
        done
        # editorconfig-checker-disable
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
      - name: loadbalanced
        protocol: layer2
        addresses:
$(printf '%b' "$ranges")
EOF
        # editorconfig-checker-enable
    fi
}

# update_repos() - Function that updates linux repositories
function update_repos {
    curl -fsSL http://bit.ly/install_pkg | PKG_UPDATE="true" bash
}

# _is_package_installed() - Function to tell if a package is installed
function _is_package_installed {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    *suse)
        CHECK_CMD="zypper search --match-exact --installed"
        ;;
    ubuntu | debian)
        CHECK_CMD="dpkg -l"
        ;;
    rhel | centos | fedora)
        CHECK_CMD="rpm -q"
        ;;
    esac
    sudo "${CHECK_CMD}" "$@" &>/dev/null
}

# _install_package() - Install specific package if doesn't exist
function _install_packages {
    sanity_pkgs=""
    for pkg in "$@"; do
        if ! _is_package_installed "$pkg"; then
            sanity_pkgs+="$pkg"
        fi
    done
    curl -fsSL http://bit.ly/install_pkg | PKG="$sanity_pkgs" bash
}

# _get_version() - Get the version number declared as environment variable or in the configuration file
function _get_version {
    krd_var_version="KRD_$(awk -v name="$1" 'BEGIN {print toupper(name)}')_VERSION"
    if [ "${!krd_var_version-}" ]; then
        echo "${!krd_var_version}"
    else
        grep "^${1}_version:" "$krd_playbooks/krd-vars.yml" | awk -F ': ' '{print $2}'
    fi
}

# get_cpu_arch() - Gets CPU architecture of the server
function get_cpu_arch {
    case "$(uname -m)" in
    x86_64)
        echo "amd64"
        ;;
    armv8* | aarch64*)
        echo "arm64"
        ;;
    armv*)
        echo "armv7"
        ;;
    esac
}

# _vercmp() - Function that compares two versions
function _vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
    "==")
        [ "$v1" = "$v2" ]
        return
        ;;
    ">")
        [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
        return
        ;;
    "<")
        [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
        return
        ;;
    ">=")
        [ "$result" = "$v2" ]
        return
        ;;
    "<=")
        [ "$result" = "$v1" ]
        return
        ;;
    *)
        echo "unrecognised op: $op"
        exit 1
        ;;
    esac
}

function _deploy_kpt_pkg {
    local pkg=$1
    local repo=${2:-https://github.com/nephio-project/catalog.git}
    local dest=${3:-${pkg##*/}}
    local revision=${4:-main}
    local for_deployment=${5:-false}

    if ! command -v kpt >/dev/null; then
        curl -s "https://i.jpillora.com/kptdev/kpt@v$(_get_version kpt)!" | bash
        kpt completion bash | sudo tee /etc/bash_completion.d/kpt >/dev/null
    fi

    [[ ! $dest =~ "/" ]] || mkdir -p "${dest%/*}"
    [ "$(ls -A "$dest")" ] || kpt pkg get "$repo/${pkg}@${revision}" "$dest" --for-deployment "$for_deployment"
    newgrp docker <<BASH
    kpt fn render $dest
BASH
    kpt live init "$dest" --force
    newgrp docker <<BASH
    kpt live apply $dest
BASH
}

function _run_argocd_cmd {
    # Installing ArgoCD CLI
    if ! command -v argocd >/dev/null; then
        argocd_version=$(_get_version argocd)
        OS="$(uname | tr '[:upper:]' '[:lower:]')"
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"

        sudo curl -fsSL -o /usr/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/$argocd_version/argocd-$OS-$ARCH"
        sudo chmod +x /usr/bin/argocd
    fi

    argocd_cmd="ARGOCD_OPTS='--port-forward-namespace argocd --port-forward' $(command -v argocd) "
    echo "$argocd_cmd $*"
    eval "$argocd_cmd $*"
}

function _run_ansible_cmd {
    local playbook=$1
    local log=$2
    local tags="${3:-all}"
    local krd_log_dir="/var/log/krd"

    pkgs=""
    for pkg in ansible pip; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    ansible_cmd="COLLECTIONS_PATHS=$galaxy_base_path sudo -E $(command -v ansible-playbook) --become --tags $tags --become-user=root "
    if [[ $KRD_ANSIBLE_DEBUG == "true" ]]; then
        ansible_cmd+="-vvv "
    fi
    ansible_cmd+="-i $krd_inventory -e ansible_ssh_common_args='' "
    echo "$ansible_cmd $playbook"
    sudo mkdir -p "$krd_log_dir"
    eval "$ansible_cmd $playbook" | sudo tee "$krd_log_dir/$log"
}

function _delete_namespace {
    local namespace="$1"
    local attempt_counter=0
    local max_attempts=12

    if ! kubectl get namespaces 2>/dev/null | grep "$namespace"; then
        return
    fi
    kubectl delete namespace "$namespace" --wait=false

    until [ "$(kubectl get all -n "$namespace" --no-headers | wc -l)" == "0" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            echo "Max attempts reached to delete resources in $namespace namespace"
            exit 1
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 5))
    done
    if kubectl get namespaces 2>/dev/null | grep "$namespace"; then
        echo "Force namespace deletion"
        # NOTE: https://stackoverflow.com/a/59667608/2727227
        if command -v kubectl-finalize_namespace >/dev/null; then
            kubectl finalize_namespace "$namespace" || :
        else
            kubectl get namespace "$namespace" -o json | tr -d "\n" |
                sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" |
                kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f - || :
        fi
    fi
}

function _install_app {
    local app=$1

    if command -v argocd >/dev/null; then
        kubectl apply -f "$KRD_FOLDER/resources/argocd/$app.yml"
        _run_argocd_cmd app sync "$app"
    else
        "_install_chart_$app"
    fi
}

function _uninstall_app {
    local app=$1

    if command -v argocd >/dev/null; then
        _run_argocd_cmd app delete "$app" --yes --cascade
    else
        _uninstall_chart "$app"
    fi
}

function _install_krew_plugin {
    local plugin=$1

    kubectl plugin list | grep -q kubectl-krew || return
    ! kubectl krew search "$plugin" | grep -q "${plugin}.*no" || kubectl krew install "$plugin"
}
