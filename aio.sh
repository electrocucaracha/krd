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
fi
if [ -n "${KRD_ACTIONS_DECLARE:-}" ]; then
    eval "${KRD_ACTIONS_DECLARE}"
fi

if ! sudo -n "true"; then
    echo ""
    echo "passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

# Validating local IP addresses in no_proxy environment variable
if [[ ${NO_PROXY+x} = "x" ]]; then
    for ip in $(hostname --ip-address || hostname -i) $(ip addr | awk "/$(ip route | grep "^default" | head -n1 | awk '{ print $5 }')\$/ { sub(/\/[0-9]*/, \"\","' $2); print $2}'); do
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$  &&  $NO_PROXY != *"$ip"* ]]; then
            echo "The $ip IP address is not defined in NO_PROXY env"
            exit 1
        fi
    done
fi

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"
    sudo zypper -n ref
    ;;

    ubuntu|debian)
    INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install"
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
    sudo "$PKG_MANAGER" updateinfo
    ;;
esac

if ! command -v wget; then
    ${INSTALLER_CMD} wget
fi
echo "Sync server's clock"
sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"

if ! command -v git; then
    ${INSTALLER_CMD} git
fi
echo "Cloning and configuring KRD project..."
if [ ! -d "${KRD_FOLDER:-/opt/krd}" ]; then
    sudo -E git clone --depth 1 https://github.com/electrocucaracha/krd "${KRD_FOLDER:-/opt/krd}"
    sudo chown -R "$USER" "${KRD_FOLDER:-/opt/krd}"
fi
cd /opt/krd || exit

is_k8s_action="false"
for value in "${KRD_ACTIONS[@]:-install_k8s}"; do
    if [[ "$value" == *k8s* ]]; then
        is_k8s_action="true"
        break
    fi
done

if [ "$is_k8s_action" == "true" ]; then
    # Setup SSH keys
    rm -f ~/.ssh/id_rsa*
    sudo mkdir -p /root/.ssh/
    echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
    if [ "$EUID" -ne "0" ]; then
        # Attempt to copy file when non root else cmd fails with 'same file' message
        sudo cp ~/.ssh/id_rsa /root/.ssh/id_rsa
    fi
    < ~/.ssh/id_rsa.pub tee --append  ~/.ssh/authorized_keys | sudo tee --append /root/.ssh/authorized_keys
    chmod og-wx ~/.ssh/authorized_keys

    hostname=$(hostname)
    sudo tee inventory/hosts.ini << EOL
[all]
$hostname

[kube-master]
$hostname

[kube-node]
$hostname

[etcd]
$hostname

[virtlet]
$hostname

[k8s-cluster:children]
kube-node
kube-master
EOL
fi

sudo -E ./node.sh

echo "Deploying KRD project"
for krd_action in "${KRD_ACTIONS[@]:-install_k8s}"; do
    ./krd_command.sh -a "$krd_action" | tee "krd_${krd_action}.log"
done
