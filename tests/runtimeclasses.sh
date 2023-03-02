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
# shellcheck source=tests/_assertions.sh
source _assertions.sh

kata_deployment_name=kata-deployment-demo
crun_deployment_name=crun-deployment-demo
gvisor_deployment_name=gvisor-deployment-demo
youki_deployment_name=youki-deployment-demo

function cleanup {
    for deployment in "$kata_deployment_name" "$crun_deployment_name" "$gvisor_deployment_name" "$youki_deployment_name"; do
        destroy_deployment "$deployment"
    done
}

function create_deployment {
    name="$1"
    runtime="$2"

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: $runtime
  name: $name
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: $runtime
  template:
    metadata:
      labels:
        app.kubernetes.io/name: $runtime
    spec:
      runtimeClassName: $runtime
      containers:
        - name: test
          image: quay.io/quay/busybox
          command: ["sleep"]
          args: ["infity"]
EOF
}

trap cleanup EXIT
trap get_status ERR

# Test
info "===== Test started ====="

if kubectl get runtimeclasses/kata-qemu >/dev/null; then
    info "+++++ Kata Containers QEMU validation:"
    create_deployment "$kata_deployment_name" "kata-qemu"
    wait_deployment "$kata_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=kata-qemu -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "kata-qemu" "$deployment_pod is not using the Kata Containers runtime"
    assert_are_not_equal "$(kubectl exec -it "$deployment_pod" -- uname -a)" "$(uname -a)" "$deployment_pod has the same kernel version than the host"
    destroy_deployment "$kata_deployment_name"
fi

if kubectl get runtimeclasses/crun >/dev/null; then
    info "+++++ crun validation:"
    create_deployment "$crun_deployment_name" "crun"
    wait_deployment "$crun_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=crun -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "crun" "$deployment_pod is not using the crun runtime"
    destroy_deployment "$crun_deployment_name"
fi

if kubectl get runtimeclasses/gvisor >/dev/null; then
    info "+++++ gvisor validation:"
    create_deployment "$gvisor_deployment_name" "gvisor"
    wait_deployment "$gvisor_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=gvisor -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "gvisor" "$deployment_pod is not using the gVisor runtime"
    destroy_deployment "$gvisor_deployment_name"
fi

if kubectl get runtimeclasses/youki >/dev/null; then
    info "+++++ youki validation:"
    create_deployment "$youki_deployment_name" "youki"
    wait_deployment "$youki_deployment_name"
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=youki -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "youki" "$deployment_pod is not using the youki runtime"
    destroy_deployment "$youki_deployment_name"
fi

info "===== Test completed ====="
