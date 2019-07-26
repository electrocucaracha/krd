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

if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
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
${INSTALLER_CMD} git

# Setup SSH keys
rm -f ~/.ssh/id_rsa*
sudo mkdir -p /root/.ssh/
echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
sudo cp ~/.ssh/id_rsa /root/.ssh/id_rsa
< ~/.ssh/id_rsa.pub tee --append  ~/.ssh/authorized_keys | sudo tee --append /root/.ssh/authorized_keys
chmod og-wx ~/.ssh/authorized_keys

echo "Cloning and configuring KRD project..."
if [ ! -d "${KRD_FOLDER:-/opt/krd}" ]; then
    sudo git clone --depth 1 https://github.com/electrocucaracha/krd "${KRD_FOLDER:-/opt/krd}"
    sudo chown -R "$USER" "${KRD_FOLDER:-/opt/krd}"
fi
cd /opt/krd || exit
sudo tee inventory/hosts.ini << EOL
[all]
localhost

[kube-master]
localhost

[kube-node]
localhost

[etcd]
localhost

[ovn-central]
localhost

[ovn-controller]
localhost

[virtlet]
localhost

[k8s-cluster:children]
kube-node
kube-master
EOL

echo "Enabling nested-virtualization"
sudo ./node.sh

echo "Deploying KRD project"
if [ -n "${KRD_ACTIONS_DECLARE:-}" ]; then
    eval "${KRD_ACTIONS_DECLARE}"
fi
for krd_action in "${KRD_ACTIONS[@]:-install_k8s}"; do
    ./krd_command.sh -a "$krd_action" | tee "krd_${krd_action}.log"
done
