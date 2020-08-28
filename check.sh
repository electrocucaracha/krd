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

function die {
    echo >&2 "$@"
    exit 1
}

function msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}

function info {
    msg "INFO" "$1"
}

function error {
    msg "ERROR" "$1"
    exit 1
}

function asserts {
    local expected=$1
    local current=$2

    if [ " $expected " != " $current " ]; then
        error "got $current, want $expected"
    fi
}

[ "$#" -eq 2 ] || die "2 arguments required, $# provided"

info "Install Integration dependencies - $1"
# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    ubuntu|debian)
        sudo apt-get update
        sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 --no-install-recommends curl qemu
    ;;
esac
curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

info "Configure SSH keys"
sudo mkdir -p /root/.ssh/
sudo cp insecure_keys/key /root/.ssh/id_rsa
cp insecure_keys/key ~/.ssh/id_rsa
sudo chmod 400 /root/.ssh/id_rsa
chown "$USER" ~/.ssh/id_rsa
chmod 400 ~/.ssh/id_rsa

info "Define target node"
cat <<EOL > config/pdf.yml
- name: aio
  os:
    name: $1
    release: $2
  networks:
    - name: public-net
      ip: "10.10.16.3"
  memory: 6144
  cpus: 2
  numa_nodes: # Total memory for NUMA nodes must be equal to RAM size
    - cpus: 0-1
      memory: 6144
  pmem:
    size: 6G # This value may affect the currentMemory libvirt tag
    slots: 2
    max_size: 8G
    vNVDIMMs:
      - mem_id: mem0
        id: nv0
        share: "on"
        path: /dev/shm
        size: 2G
  volumes:
    - name: sdb
      size: 25
      mount: /var/lib/docker/
    - name: sdc
      size: 10
  roles:
    - kube-master
    - etcd
    - kube-node
    - virtlet
    - qat-node
EOL

info "Provision target node"
sudo vagrant up

KRD_DEBUG=true
KRD_KUBE_VERSION=v1.17.6
KRD_KUBESPRAY_VERSION=v2.13.1
export KRD_DEBUG KRD_KUBE_VERSION KRD_KUBESPRAY_VERSION

info "Provision Kubernetes cluster"
./krd_command.sh -a install_k8s

info "Validate Kubernetes execution"
kubectl get nodes -o wide
asserts "$KRD_KUBE_VERSION" "$(kubectl version --short | awk 'FNR==2{print $3}')"
pushd /opt/kubespray > /dev/null
asserts "$KRD_KUBESPRAY_VERSION" "$(git describe --abbrev=0 --tags)"
popd > /dev/null
