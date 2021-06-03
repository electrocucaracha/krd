#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
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

kata_deployment_name=kata-deployment-demo
crun_deployment_name=crun-deployment-demo

function cleanup {
    destroy_deployment "$kata_deployment_name"
    destroy_deployment "$crun_deployment_name"
}

trap cleanup EXIT
trap get_status ERR

# Test
info "===== Test started ====="

if kubectl get runtimeclasses/kata-qemu; then
    info "+++++ Kata Containers QEMU validation:"
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: kata
  name: $kata_deployment_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kata
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kata
    spec:
      runtimeClassName: kata-qemu
      containers:
        - name: test
          image: busybox
          command: ["sleep"]
          args: ["infity"]
EOF
    wait_deployment "$kata_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=kata -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "kata-qemu" "$deployment_pod is not using the Kata Containers runtime"
    assert_are_not_equal "$(kubectl exec -it "$deployment_pod" -- uname -a)" "$(uname -a)" "$deployment_pod has the same kernel version than the host"
fi

if kubectl get runtimeclasses/crun; then
    info "+++++ crun validation:"
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: crun
  name: $crun_deployment_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: crun
  template:
    metadata:
      labels:
        app.kubernetes.io/name: crun
    spec:
      runtimeClassName: crun
      containers:
        - name: test
          image: busybox
          command: ["sleep"]
          args: ["infity"]
EOF
    wait_deployment "$crun_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=crun -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "crun" "$deployment_pod is not using the crun runtime"
fi

info "===== Test completed ====="
