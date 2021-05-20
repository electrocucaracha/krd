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

source defaults.env
if [[ "$KRD_DEBUG" == "true" ]]; then
    set -o xtrace
fi

# _get_kube_version() - Get the Kubernetes version used or installed on the remote cluster
function _get_kube_version {
    if command -v kubectl; then
        kubectl version --short | grep -e "Server" | awk -F ': ' '{print $2}'
    elif [ -f "$KRD_FOLDER/k8s-cluster.yml" ]; then
        grep kube_version "$KRD_FOLDER/k8s-cluster.yml" | awk '{ print $2}'
    elif [ -n "${KRD_KUBE_VERSION}" ]; then
        echo "${KRD_KUBE_VERSION}"
    else
        echo "v1.19.9"
    fi
}

# _install_kubespray() - Download Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)

    # NOTE: bindep prints a multiline's output
    # shellcheck disable=SC2005
    pkgs="$(echo "$(bindep kubespray -b)")"
    if [ "$KRD_DOWNLOAD_LOCALHOST" == "true" ] && ! command -v docker; then
        pkgs+=" docker"
    fi
    if ! command -v kubectl || ! kubectl krew version &>/dev/null; then
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

        PIP_CMD="sudo -E $(command -v pip)"

        # This ensures that ansible is previously not installed
        if pip show ansible; then
            ansible_path="$(pip show ansible | grep Location | awk '{ print $2 }')/ansible"
            $PIP_CMD uninstall ansible -y
            sudo rm -rf "$ansible_path"
        fi
        if command -v pipx && pipx list | grep -q ansible-base; then
            sudo -E "$(command -v pipx)" uninstall ansible-base
        fi

        $PIP_CMD install --no-cache-dir -r ./requirements.txt
        make mitogen
        popd
    fi

    mkdir -p "$krd_inventory_folder/group_vars/"
    cat << EOF > "$krd_inventory_folder/group_vars/all.yml"
override_system_hostname: false
docker_dns_servers_strict: false
EOF
    if [ "$KRD_ANSIBLE_DEBUG" == "true" ]; then
        echo "kube_log_level: 5" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    else
        echo "kube_log_level: 2" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${HTTP_PROXY:-}" ]; then
        echo "http_proxy: \"$HTTP_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${HTTPS_PROXY:-}" ]; then
        echo "https_proxy: \"$HTTPS_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
    fi
    if [ -n "${NO_PROXY:-}" ]; then
        echo "no_proxy: \"$NO_PROXY\"" | tee --append "$krd_inventory_folder/group_vars/all.yml"
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
    fi
    export KRD_DOWNLOAD_LOCALHOST=$KRD_DOWNLOAD_RUN_ONCE
    export KUBESPRAY_ETCD_KUBELET_DEPLOYMENT_TYPE
    envsubst < k8s-cluster.tpl > "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    if [ -n "${KRD_KUBE_VERSION:-}" ]; then
        sed -i "s/^kube_version: .*$/kube_version: ${KRD_KUBE_VERSION}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
    if [ -n "${KRD_MANUAL_DNS_SERVER:-}" ]; then
        sed -i "s/^manual_dns_server: .*$/manual_dns_server: $KRD_MANUAL_DNS_SERVER/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    fi
    if [ -n "${KRD_REGISTRY_MIRRORS_LIST:-}" ] && [ "$KRD_CONTAINER_RUNTIME" != "containerd" ]; then
        if [ "$KRD_CONTAINER_RUNTIME" == "docker" ]; then
            echo "docker_registry_mirrors:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            for mirror in ${KRD_REGISTRY_MIRRORS_LIST//,/ }; do
                echo "  - $mirror" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            done
        elif [ "$KRD_CONTAINER_RUNTIME" == "crio" ]; then
            echo "crio_registries:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            for mirror in ${KRD_REGISTRY_MIRRORS_LIST//,/ }; do
                echo "  - ${mirror#*//}" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            done
        fi
    fi
    if [ -n "${KRD_INSECURE_REGISTRIES_LIST:-}" ] && [ "$KRD_CONTAINER_RUNTIME" != "containerd" ]; then
        echo "${KRD_CONTAINER_RUNTIME}_insecure_registries:" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        for registry in ${KRD_INSECURE_REGISTRIES_LIST//,/ }; do
            echo "  - $registry" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        done
    fi
    if [ -n "${KRD_DNS_ETCHOSTS_DICT:-}" ]; then
        echo "dns_etchosts: |" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        for etchost_entry in ${KRD_DNS_ETCHOSTS_DICT//,/ }; do
            echo "  ${etchost_entry%-*} ${etchost_entry#*-}" | tee --append "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        done
    fi
}

# install_metallb() - Install MetalLB services
function install_metallb {
    metallb_version=$(_get_version metallb)
    if [ -z "${KRD_METALLB_ADDRESS_POOLS:-}" ]; then
        declare -A KRD_METALLB_ADDRESS_POOLS=(
    ["default"]="10.10.16.110-10.10.16.120,10.10.16.240-10.10.16.250"
    )
    fi

    if ! kubectl get namespaces/metallb-system --no-headers -o custom-columns=name:.metadata.name; then
        kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$metallb_version/manifests/namespace.yaml"
        kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/$metallb_version/manifests/metallb.yaml"
        if ! kubectl get secret/memberlist -n metallb-system --no-headers -o custom-columns=name:.metadata.name; then
            kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
        fi
    fi

    wait_for_pods metallb-system

    address_pools=""
    for pool in "${!KRD_METALLB_ADDRESS_POOLS[@]}"; do
        ranges=""
        addresses=${KRD_METALLB_ADDRESS_POOLS[$pool]}
        for range in ${addresses//,/ }; do
            ranges+="          - ${range}\n"
        done

        address_pools+=$(cat <<EOF
      - name: $pool
        protocol: layer2
        addresses:
$(printf '%b' "$ranges")
EOF
)
    done

   cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
$address_pools
EOF
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
        ubuntu|debian)
            CHECK_CMD="dpkg -l"
        ;;
        rhel|centos|fedora)
            CHECK_CMD="rpm -q"
        ;;
    esac
    sudo "${CHECK_CMD}" "$@" &> /dev/null
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
    if [ "${!krd_var_version:-}" ]; then
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
        armv8*|aarch64*)
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
            die $LINENO "unrecognised op: $op"
            ;;
    esac
}

function _run_ansible_cmd {
    local playbook=$1
    local log=$2

    ansible_cmd="ANSIBLE_ROLES_PATH=/tmp/galaxy-roles sudo -E $(command -v ansible-playbook) --become "
    if [[ "$KRD_ANSIBLE_DEBUG" == "true" ]]; then
        ansible_cmd+="-vvv "
    fi
    ansible_cmd+="-i $krd_inventory "
    echo "$ansible_cmd $playbook"
    eval "$ansible_cmd $playbook" | tee "$log"
}

function _delete_namespace {
    local namespace="$1"
    local attempt_counter=0
    local max_attempts=12

    if ! kubectl get namespaces 2>/dev/null | grep  "$namespace"; then
        return
    fi
    kubectl delete namespace "$namespace" --wait=false

    until [ "$(kubectl get all -n "$namespace" --no-headers | wc -l)" == "0" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep 5
    done
}

# Requirements
if ! command -v curl > /dev/null; then
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
        ;;
    esac
fi
if ! command -v bindep > /dev/null; then
    curl -fsSL http://bit.ly/install_bin | bash
else
    pkgs="$(bindep -b || :)"
    if [ "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi
fi

# Configuration values
KRD_FOLDER="$(git rev-parse --show-toplevel)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_playbooks=$KRD_FOLDER/playbooks
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray
if [[ "$KRD_DEBUG" == "true" ]]; then
    set -o xtrace
fi
