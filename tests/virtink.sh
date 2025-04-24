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

function cleanup {
    kubectl delete -f resources/virtink/
}

# Setup
kubectl apply -f resources/virtink/
trap cleanup EXIT

# Test
info "===== Test started ====="

vm_name="ubuntu-container-rootfs"
kubectl wait vm "$vm_name" --for jsonpath='{.status.phase}'=Running --timeout -60s
pod_name=$(kubectl get vm "$vm_name" -o jsonpath='{.status.vmPodName}')
assert_are_not_equal "$(kubectl run "ssh-$vm_name" --rm --image=alpine --restart=Never -it -- uname -a)" "$(uname -a)" "$pod_name has the same kernel version than the host"

info "===== Test completed ====="
