#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020,2025
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

function cleanup {
    destroy_deployment runtime-deployment
}

trap cleanup EXIT
trap get_status ERR

# Test
info "===== Test started ====="

for runtimeclass in $(kubectl get runtimeclasses.node.k8s.io -o name); do
    info "+++++ ${runtimeclass#*/} validation:"
    kubectl apply -f "resources/runtimeclasses/${runtimeclass#*/}.yml"
    wait_deployment runtime-deployment
    deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name="${runtimeclass#*/}" -o jsonpath='{.items[0].metadata.name}')

    info "$deployment_pod assertions:"
    assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
    assert_contains "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "${runtimeclass#*/}" "$deployment_pod is not using the ${runtimeclass#*/}"
    kubectl delete -f "resources/runtimeclasses/${runtimeclass#*/}.yml"
done

info "===== Test completed ====="
