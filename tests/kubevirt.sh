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

# shellcheck source=tests/_functions.sh
source _functions.sh

# Setup
kubectl delete vm testvm --ignore-not-found=true

# Test
info "===== Test started ====="

cat << EOL | kubectl apply -f -
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  name: testvm
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: tiny  #  tiny(1 core, 1 Gi memory), small (1 core, 2 Gi memory), medium (1 core, 4 Gi memory), large (2 cores, 8 Gi memory). 
        kubevirt.io/domain: testvm
    spec:
      domain:
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinitdisk
              disk:
                bus: virtio
          interfaces:
          - name: default
            bridge: {}
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      volumes:
        - name: containerdisk
          containerDisk:
            image: kubevirt/cirros-registry-disk-demo
        - name: cloudinitdisk
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
EOL

kubectl get vms
kubectl virt start testvm
kubectl wait --for=condition=ready vmis testvm --timeout=5m > /dev/null
vm_pod=$(kubectl get pods -o jsonpath='{.items[0].metadata.name}' | grep virt-launcher-testvm)
info "$vm_pod details:"
kubectl logs "$vm_pod" -c compute | jq -R "fromjson? | .msg"
info "$vm_pod assertions:"
assert_non_empty "$(kubectl logs "$vm_pod" -c compute | grep 'Successfully connected to domain notify socket at')" "testvm unsuccessfully created"
#kubectl virt console testvm

info "===== Test completed ====="

# Teardown
kubectl delete vm testvm
