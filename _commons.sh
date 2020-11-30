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

# _install_kubespray() - Donwload Kubespray binaries
function _install_kubespray {
    echo "Deploying kubernetes"
    kubespray_version=$(_get_version kubespray)

    # NOTE: bindep prints a multiline's output
    # shellcheck disable=SC2005
    pkgs="$(echo "$(bindep kubespray -b)")"
    for pkg in docker kubectl; do
        if ! command -v "$pkg"; then
            pkgs+=" $pkg"
        fi
    done
    if [ -n "$pkgs" ]; then
        curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
    fi

    if [[ ! -d $kubespray_folder ]]; then
        echo "Download kubespray binaries"

        sudo -E git clone "${KRD_KUBESPRAY_REPO:-https://github.com/kubernetes-sigs/kubespray}" "$kubespray_folder"
        sudo chown -R "$USER:$USER" "$kubespray_folder"
        pushd "$kubespray_folder"
        if [ "$kubespray_version" != "master" ]; then
            git checkout -b "${kubespray_version#"origin/"}" "$kubespray_version"
        fi
        PIP_CMD="sudo -E $(command -v pip)"
        # This ensures that ansible is previously not installed
        if command -v ansible; then
            sitepackages_path=$(pip show ansible | grep Location | awk '{ print $2 }')
            $PIP_CMD uninstall ansible -y
            sudo rm -rf "$sitepackages_path/ansible"
        fi
        $PIP_CMD install --no-cache-dir -r ./requirements.txt
        make mitogen
        popd

        rm -rf "$krd_inventory_folder"/group_vars/
        mkdir -p "$krd_inventory_folder/group_vars/"
        cp "$KRD_FOLDER/k8s-cluster.yml" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        if [ "${KRD_ANSIBLE_DEBUG:-false}" == "true" ]; then
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
        sed -i "s/^kube_network_plugin_multus: .*$/kube_network_plugin_multus: ${KRD_MULTUS_ENABLED:-false}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
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
            # TODO: Remove this condition once this PR 6830 is merged
            if [ "${KRD_CONTAINER_RUNTIME}" == "containerd" ]; then
                sed -i "s/^kata_containers_enabled: .*$/kata_containers_enabled: ${KRD_KATA_CONTAINERS_ENABLED:-false}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
            fi
        fi
        sed -i "s/^kube_network_plugin: .*$/kube_network_plugin: ${KRD_NETWORK_PLUGIN:-flannel}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        sed -i "s/^cert_manager_enabled: .*$/cert_manager_enabled: ${KRD_CERT_MANAGER_ENABLED:-true}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        sed -i "s/^ingress_nginx_enabled: .*$/ingress_nginx_enabled: ${KRD_INGRESS_NGINX_ENABLED:-true}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
        sed -i "s/^dashboard_enabled: .*$/dashboard_enabled: ${KRD_DASHBOARD_ENABLED:-false}/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
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
    if [[ "${KRD_ANSIBLE_DEBUG:-false}" == "true" ]]; then
        ansible_cmd+="-vvv "
    fi
    ansible_cmd+="-i $krd_inventory "
    echo "$ansible_cmd $playbook"
    eval "$ansible_cmd $playbook" | tee "$log"
}

# Requirements
if ! command -v curl; then
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
        ;;
    esac
fi
if ! command -v bindep; then
    _install_packages bindep
fi
pkgs="$(bindep -b || :)"
if [ "$pkgs" ]; then
    curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
fi

# Configuration values
KRD_FOLDER="$(git rev-parse --show-toplevel)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_playbooks=$KRD_FOLDER/playbooks
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi
