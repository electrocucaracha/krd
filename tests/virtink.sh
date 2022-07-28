#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2022
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=tests/_functions.sh
source _functions.sh
# shellcheck source=tests/_assertions.sh
source _assertions.sh

vm_name=ubuntu-container-rootfs

function cleanup {
    kubectl delete vm $vm_name --ignore-not-found
}

# Setup
cat <<EOF | kubectl apply -f -
apiVersion: virt.virtink.smartx.com/v1alpha1
kind: VirtualMachine
metadata:
  name: $vm_name
spec:
  instance:
    memory:
      size: 1Gi
    kernel:
      image: smartxworks/virtink-kernel-5.15.12
      cmdline: "console=ttyS0 root=/dev/vda rw"
    disks:
      - name: ubuntu
      - name: cloud-init
    interfaces:
      - name: pod
  volumes:
    - name: ubuntu
      containerRootfs:
        image: smartxworks/virtink-container-rootfs-ubuntu
        size: 4Gi
    - name: cloud-init
      cloudInit:
        userData: |-
          #cloud-config
          password: password
          chpasswd: { expire: False }
          ssh_pwauth: True
  networks:
    - name: pod
      pod: {}
EOF
sleep 5
trap cleanup EXIT

# Test
info "===== Test started ====="

kubectl wait vm ubuntu-container-rootfs --for jsonpath='{.status.phase}'=Running --timeout -1s
pod_name=$(kubectl get vm "$vm_name" -o jsonpath='{.status.vmPodName}')
assert_are_not_equal "$(kubectl run "ssh-$vm_name" --rm --image=alpine --restart=Never -it -- uname -a)" "$(uname -a)" "$pod_name has the same kernel version than the host"

info "===== Test completed ====="
