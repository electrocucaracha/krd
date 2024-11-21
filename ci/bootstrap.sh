#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=ci/_common.sh
source _common.sh

function destroy_vm {
    local vm="$1"

    info "Destroying $vm instance..."
    # NOTE: Shutdown instances avoids VBOX_E_INVALID_OBJECT_STATE issues
    $VAGRANT_CMD halt "$vm"
    $VAGRANT_CMD destroy "$vm" -f
}

info "Define target node"
if [[ ${TEST_MULTINODE:-false} == "false" ]]; then
    # editorconfig-checker-disable
    cat <<EOL >../config/pdf.yml
- name: aio
  os:
    name: ${OS:-ubuntu}
    release: ${RELEASE:-jammy}
  networks:
    - name: public-net
      ip: "10.10.16.3"
  memory: ${MEMORY:-6144}
  cpus: 3
  sriov_numvfs: 6
  numa_nodes: # Total memory for NUMA nodes must be equal to RAM size
    - cpus: 0-2
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
    - name: sdc
      size: 20
      mount: /mnt/disks/vol1
      controller: ${VBOX_CONTROLLER:-Virtual I/O Device SCSI controller}
      port: 2
      device: 0
    - name: sdd
      size: 20
      mount: /mnt/disks/vol2
      controller: ${VBOX_CONTROLLER:-Virtual I/O Device SCSI controller}
      port: 3
      device: 0
    - name: sde
      size: 20
      mount: /mnt/disks/vol3
      controller: ${VBOX_CONTROLLER:-Virtual I/O Device SCSI controller}
      port: 4
      device: 0
  roles:
    - kube-master
    - etcd
    - kube-node
    - qat-node
EOL
    # editorconfig-checker-enable
    destroy_vm aio
else
    # editorconfig-checker-disable
    cat <<EOL >../config/pdf.yml
- name: controller
  os:
    name: ${OS:-ubuntu}
    release: ${RELEASE:-jammy}
  networks:
    - name: public-net
      ip: "10.10.16.3"
  memory: 4096
  cpus: 1
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
EOL
    # editorconfig-checker-enable
    for i in {1..2}; do
        # editorconfig-checker-disable
        cat <<EOL >>../config/pdf.yml
- name: worker0${i}
  os:
    name: ${OS:-ubuntu}
    release: ${RELEASE:-jammy}
  networks:
    - name: public-net
      ip: "10.10.16.$((i + 3))"
  memory: 4096
  cpus: 1
  sriov_numvfs: 3
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
    - kube-node
EOL
        # editorconfig-checker-enable
    done
    destroy_vm controller
    for i in {1..2}; do
        destroy_vm "worker0${i}"
    done
fi

info "Provision target node"
$VAGRANT_CMD_UP
