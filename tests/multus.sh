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
# shellcheck source=tests/_assertions.sh
source _assertions.sh

multus_deployment_name=multus-test
bridge_net_name=bridge-test
subnet_prefix="10.10.10"
subnet="${subnet_prefix}.0/24"

function cleanup {
    kubectl delete network-attachment-definitions.k8s.cni.cncf.io -A --selector=app.kubernetes.io/name=multus
    destroy_deployment "$multus_deployment_name"
}

function create_deployment {
    local net_definition=$1

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $multus_deployment_name
  labels:
    app.kubernetes.io/name: multus
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: multus
  template:
    metadata:
      labels:
        app.kubernetes.io/name: multus
      annotations:
$net_definition
    spec:
      containers:
        - name: instance
          image: busybox
          command:
            - sleep
          args:
            - "120"
EOF
    wait_deployment "$multus_deployment_name"
}

trap cleanup EXIT
trap get_status ERR

# Setup
cat <<EOF | kubectl apply -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: $bridge_net_name
  labels:
    app.kubernetes.io/name: multus
spec:
  config: '{
    "cniVersion": "0.4.0",
    "name": "bridgenet",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "$subnet"
    }
}'
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: $bridge_net_name
  namespace: kube-system
  labels:
    app.kubernetes.io/name: multus
spec:
  config: '{
    "cniVersion": "0.4.0",
    "name": "bridgenet",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "$subnet"
    }
}'
EOF

# Test
info "===== Test started ====="

info "+++++ Multiple Network Interfaces validation:"
net_definition=$(cat <<EOF
        k8s.v1.cni.cncf.io/networks: '[
          { "name": "$bridge_net_name", "interfaceRequest": "eth1" },
          { "name": "$bridge_net_name", "interfaceRequest": "eth2" }
        ]'
EOF
)
create_deployment "$net_definition"
deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=multus -o jsonpath='{.items[0].metadata.name}')
info "$deployment_pod details:"
kubectl exec -it "$deployment_pod" -- ip link
info "$deployment_pod assertions:"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth1)" "$deployment_pod pod doesn't contain eth1 nic"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth1 | awk '/inet addr/{print substr($2,6)}' | grep "$subnet_prefix" )" "$deployment_pod pod eth1 ip doesn't belong to $bridge_net_name network"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth2)" "$deployment_pod pod doesn't contain eth2 nic"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth2 | awk '/inet addr/{print substr($2,6)}' | grep "$subnet_prefix" )" "$deployment_pod pod eth2 ip doesn't belong to $bridge_net_name network"
destroy_deployment "$multus_deployment_name"

info "+++++ Default Network Interfaces validation:"
net_definition=$(cat <<EOF
        v1.multus-cni.io/default-network: $bridge_net_name
EOF
)
create_deployment "$net_definition"
deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=multus -o jsonpath='{.items[0].metadata.name}')
info "$deployment_pod details:"
kubectl exec -it "$deployment_pod" -- ip link
info "$deployment_pod assertions:"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth0)" "$deployment_pod pod doesn't contain eth0 nic"
assert_non_empty "$(kubectl exec -it "$deployment_pod" -- ifconfig eth0 | awk '/inet addr/{print substr($2,6)}' | grep "$subnet_prefix" )" "$deployment_pod pod ip doesn't belong to $bridge_net_name network"
destroy_deployment "$multus_deployment_name"

info "===== Test completed ====="
