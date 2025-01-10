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
set -o nounset
set -o pipefail
if [ "${KRD_DEBUG:-false}" == "true" ]; then
    set -o xtrace
    export PKG_DEBUG=true
fi

# All-in-One deployments can't take advantage of image caching.
export KRD_DOWNLOAD_LOCALHOST=false
krd_actions_list=${KRD_ACTIONS_LIST:-install_k8s}

# Validators
if ! sudo -n "true"; then
    echo ""
    echo "passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

if [[ $(id -u) -eq 0 ]]; then
    echo ""
    echo "This script needs to be executed without using sudo command."
    echo ""
    exit 1
fi

# Install dependencies
# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
curl -fsSL http://bit.ly/install_pkg | PKG_UPDATE=true PKG_COMMANDS_LIST="hostname,wget,git" bash

# Validating local IP addresses in no_proxy environment variable
if [[ ${NO_PROXY+x} == "x" ]]; then
    for ip in $(hostname --ip-address || hostname -i) $(ip addr | awk "/$(ip route | grep "^default" | head -n1 | awk '{ print $5 }')\$/ { sub(/\/[0-9]*/, \"\","' $2); print $2}'); do
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && $NO_PROXY != *"$ip"* ]]; then
            echo "The $ip IP address is not defined in NO_PROXY env"
            exit 1
        fi
    done
fi

echo "Sync server's clock"
sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"

# Configuring KRD project
krd_folder="${KRD_FOLDER:-/opt/krd}"
if [ ! -d "$krd_folder" ]; then
    echo "Cloning and configuring KRD project..."
    sudo -E git clone --depth 1 https://github.com/electrocucaracha/krd "$krd_folder"
    sudo chown -R "$USER": "$krd_folder"
fi
cd "$krd_folder" || exit

if [[ $krd_actions_list == *k8s* ]]; then
    # Setup SSH keys
    rm -f ~/.ssh/id_rsa*
    sudo mkdir -p /root/.ssh/
    echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
    if [ "$EUID" -ne "0" ]; then
        # Attempt to copy file when non root else cmd fails with 'same file' message
        sudo cp ~/.ssh/id_rsa /root/.ssh/id_rsa
    fi
    tee <~/.ssh/id_rsa.pub --append ~/.ssh/authorized_keys | sudo tee --append /root/.ssh/authorized_keys
    chmod og-wx ~/.ssh/authorized_keys

    hostname=$(hostname)
    ip_address=$(hostname -I | awk '{print $1}')
    sudo tee inventory/hosts.ini <<EOL
[all]
$hostname

[kube_control_plane]
$hostname	ansible_host=$ip_address ip=$ip_address

[kube_node]
$hostname	ansible_host=$ip_address ip=$ip_address

[etcd]
$hostname	ansible_host=$ip_address ip=$ip_address

[k8s_cluster:children]
kube_node
kube_control_plane
EOL
fi

sudo -E ./node.sh

# Resolving Docker previous installation issues
if [ "${KRD_CONTAINER_RUNTIME:-docker}" == "docker" ] && command -v docker; then
    echo "Removing docker previous installation"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        systemctl --all --type service | grep -q docker && sudo systemctl stop docker --now
        sudo apt-get purge -y docker-ce docker-ce-cli moby-engine moby-cli moby-buildx || true
        sudo rm -rf /var/lib/docker /etc/docker
        sudo rm -rf /var/run/docker.sock
        sudo rm -f "$(sudo netstat -npl | grep docker | awk '{print $NF}')"
        ;;
    esac
fi

echo "Deploying KRD project"
for krd_action in ${krd_actions_list//,/ }; do
    ./krd_command.sh -a "$krd_action" | tee "krd_${krd_action}.log"
done

if [ -f /etc/apt/sources.list.d/docker.list ] && [ -f /etc/apt/sources.list.d/download_docker_com_linux_ubuntu.list ]; then
    sudo rm /etc/apt/sources.list.d/docker.list
fi
