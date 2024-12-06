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

# shellcheck source=tests/_functions.sh
source _functions.sh
# shellcheck source=tests/_assertions.sh
source _assertions.sh

function cleanup {
    kubectl rook-ceph health || :
    echo "yes-really-destroy-cluster" | kubectl rook-ceph destroy-cluster
    kubectl delete -f resources/rook --ignore-not-found
}

# Setup
kubectl apply -f resources/rook/replicapool.yaml
sleep 3
kubectl apply -f resources/rook/cluster-test.yaml
trap cleanup EXIT

attempt_counter=0
max_attempts=5
until [[ "$(kubectl get CephCluster -n rook-ceph my-cluster -o jsonpath='{.status.phase}')" == "Ready" ]]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
        error "Max attempts reached"
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep $((attempt_counter * 15))
done
wait_deployment rook-ceph

info "Ceph Stats:"
kubectl rook-ceph rados df
kubectl rook-ceph ceph df

# Test
info "===== Test started ====="

assert_contains "$(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name)" "rook-ceph-block" "Rook Ceph Block storage class doesn't exist"
assert_are_equal "$(kubectl get storageclasses -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')" "rook-ceph-block" "Rook Ceph Block isn't default storage class"
assert_contains "$(kubectl rook-ceph health)" "HEALTH_OK" "Ceph clusters is not OK"
assert_contains "$(kubectl rook-ceph rados lspools)" "replicapool" "RADOS cluster"

info "===== Test completed ====="
