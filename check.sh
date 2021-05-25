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

function exit_trap {
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb):"
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    echo "Environment variables:"
    env | grep "KRD"
    if command -v kubectl; then
        kubectl get all -A -o wide
        kubectl get nodes -o wide
    fi
}

[ "$#" -eq 2 ] || error "2 arguments required, $# provided"

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
    - qat-node
EOL

info "Provision target node"
sudo vagrant up

info "Provision Kubernetes cluster"
trap exit_trap ERR
KRD_DEBUG=true ./krd_command.sh -a install_k8s
trap ERR

info "Validate Kubernetes execution"
asserts "${KRD_KUBE_VERSION:-v1.19.9}" "$(kubectl version --short | awk 'FNR==2{print $3}')"
pushd /opt/kubespray > /dev/null
asserts "${KRD_KUBESPRAY_VERSION:-v2.16.0}" "$(git describe --abbrev=0 --tags)"
popd > /dev/null
