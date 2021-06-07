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

# assert_equals() - This assertion checks if the input is equal to another value
function asserts_equals {
    local expected=$1
    local current=$2

    if [ " $expected " != " $current " ]; then
        error "got $current, want $expected"
    fi
}


# assert_contains() - This assertion checks if the input contains another value
function assert_contains {
    local expected=$1
    local input=$2

    if [[ "$input" != *"$expected"* ]]; then
        error "$input doesn't contains $expected"
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

if ! command -v vagrant > /dev/null; then
    # NOTE: Shorten link -> https://github.com/electrocucaracha/bootstrap-vagrant
    curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash
fi

if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
    info "Configure SSH keys"
    sudo mkdir -p /root/.ssh/
    sudo cp insecure_keys/key /root/.ssh/id_rsa
    cp insecure_keys/key ~/.ssh/id_rsa
    sudo chmod 400 /root/.ssh/id_rsa
    chown "$USER" ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
fi

info "Define target node"
cat <<EOL > config/pdf.yml
- name: aio
  os:
    name: $1
    release: $2
  networks:
    - name: public-net
      ip: "10.10.16.3"
  memory: ${MEMORY:-6144}
  cpus: 2
  numa_nodes: # Total memory for NUMA nodes must be equal to RAM size
    - cpus: 0-1
      memory: ${MEMORY:-6144}
  pmem:
    size: ${MEMORY:-6144}M # This value may affect the currentMemory libvirt tag
    slots: 2
    max_size: 128G
    vNVDIMMs:
      - mem_id: mem0
        id: nv0
        share: "on"
        path: /dev/shm
        size: 2G
  storage_controllers:
    - name: Virtual I/O Device SCSI controller
      type: virtio-scsi
      controller: VirtIO
  volumes:
    - name: sdb
      size: 25
      mount: /var/lib/docker/
      controller: ${VBOX_CONTROLLER:-Virtual I/O Device SCSI controller}
      port: 1
      device: 0
  roles:
    - kube-master
    - etcd
    - kube-node
    - qat-node
EOL

info "Provision target node"
VAGRANT_CMD=""
if [[ "${SUDO_VAGRANT_CMD:-false}" == "true" ]]; then
    VAGRANT_CMD="sudo -H"
fi
VAGRANT_CMD+=" $(command -v vagrant)"
VAGRANT_CMD_UP="$VAGRANT_CMD up --no-destroy-on-error"
VAGRANT_CMD_SSH_INSTALLER="$VAGRANT_CMD ssh installer --"

$VAGRANT_CMD_UP

info "Provision Kubernetes cluster"
if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
    trap exit_trap ERR
    KRD_DEBUG=true ./krd_command.sh -a install_k8s
    trap ERR

    info "Validate Kubernetes execution"
    asserts_equals "${KRD_KUBE_VERSION:-v1.20.7}" "$(kubectl version --short | awk 'FNR==2{print $3}')"
    pushd /opt/kubespray > /dev/null
    asserts_equals "${KRD_KUBESPRAY_VERSION:-v2.16.0}" "$(git describe --abbrev=0 --tags)"
    popd > /dev/null

    if [[ "${KRD_ENABLE_TESTS:-false}" == "true" ]]; then
        pushd tests > /dev/null
        KRD_DEBUG=false ./check.sh kong metallb istio haproxy kubevirt
        popd > /dev/null
    fi
    if [[ "${TEST_VIRTLET:-false}" == "true" ]]; then
        KRD_DEBUG=false KRD_ENABLE_TESTS=true KRD_DEBUG=true KRD_ADDONS_LIST=virtlet ./krd_command.sh -a install_k8s_addons
    fi
    if [[ "${TEST_RUNTIMECLASSES:-false}" == "true" ]]; then
        pushd tests > /dev/null
        KRD_DEBUG=false ./runtimeclasses.sh
        popd > /dev/null
    fi
else
    $VAGRANT_CMD_UP installer
    info "Validate Kubernetes execution"

    assert_contains "${KRD_KUBE_VERSION:-v1.20.7}" "$($VAGRANT_CMD_SSH_INSTALLER "kubectl version --short | awk 'FNR==2{print \$3}'")"
    assert_contains "${KRD_KUBESPRAY_VERSION:-v2.16.0}" "$($VAGRANT_CMD_SSH_INSTALLER "cd /opt/kubespray; git describe --abbrev=0 --tags")"

    if [[ "${KRD_ENABLE_TESTS:-false}" == "true" ]]; then
        $VAGRANT_CMD_SSH_INSTALLER "cd /vagrant/tests; KRD_DEBUG=false ./check.sh kong metallb istio haproxy kubevirt"
    fi
    if [[ "${TEST_VIRTLET:-false}" == "true" ]]; then
        $VAGRANT_CMD_SSH_INSTALLER "cd /vagrant/; KRD_DEBUG=false KRD_ENABLE_TESTS=true KRD_ADDONS_LIST=virtlet ./krd_command.sh -a install_k8s_addons"
    fi
    if [[ "${TEST_RUNTIMECLASSES:-false}" == "true" ]]; then
        $VAGRANT_CMD_SSH_INSTALLER "cd /vagrant/tests; KRD_DEBUG=false ./runtimeclasses.sh"
    fi
fi
