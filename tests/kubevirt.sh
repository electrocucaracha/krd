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

function cleanup {
    attempt_counter=0
    max_attempts=5

    kubectl virt stop testvm || :
    kubectl delete -f resources/kubevirt

    while [[ -n $(kubectl get pods -o jsonpath='{.items[*].metadata.name}' -l vm.kubevirt.io/name=testvm) ]]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            error "Max attempts reached"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 10))
    done
}

trap cleanup EXIT

# Test
info "===== Test started ====="

kubectl apply -f resources/kubevirt
kubectl get vms
[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ] && export PATH="$PATH:${KREW_ROOT:-$HOME/.krew}/bin"
! kubectl plugin list | grep -q virt && kubectl krew install virt
kubectl virt start testvm
kubectl wait --for=condition=Ready vmis testvm --timeout=5m >/dev/null
vm_pod=$(kubectl get pods -o jsonpath='{.items[0].metadata.name}' -l vm.kubevirt.io/name=testvm)
kubectl wait --for=condition=Ready pod "$vm_pod" --timeout=5m >/dev/null

info "$vm_pod assertions:"
assert_non_empty "$(kubectl logs "$vm_pod" -c compute | grep 'Successfully connected to domain notify socket at')" "testvm unsuccessfully created"
attempt_counter=0
max_attempts=5
until [[ "$(kubectl logs "$vm_pod" -c guest-console-log)" == *"printed from cloud-init userdata"* ]]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
        error "testvm unsuccessfully ran cloud-init"
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep $((attempt_counter * 5))
done

info "$vm_pod details:"
kubectl logs "$vm_pod" -c compute | jq -R "fromjson? | .msg"
kubectl logs "$vm_pod" -c guest-console-log
#kubectl virt console testvm

info "===== Test completed ====="
