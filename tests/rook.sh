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
    kubectl delete -f resources/rook
    kubectl patch cephblockpools.ceph.rook.io replicapool -n rook-ceph-system --type='json' -p="[{'op': 'replace', 'path': '/spec/replicated/size', 'value': 3}]"
}

# Setup
kubectl patch cephblockpools.ceph.rook.io replicapool -n rook-ceph-system --type='json' -p="[{'op': 'replace', 'path': '/spec/replicated/size', 'value': 1}]"
sleep 3
kubectl apply -f resources/rook
trap cleanup EXIT

attempt_counter=0
max_attempts=5
until [[ "$(kubectl get CephCluster -n rook-ceph-system my-cluster -o jsonpath='{.status.phase}')" == "Ready" ]]; do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
        error "Max attempts reached"
    fi
    attempt_counter=$((attempt_counter+1))
    sleep $((attempt_counter*15))
done
wait_deployment rook-ceph-tools rook-ceph-system

info "Ceph Stats:"
# Rook Toolbox - Common tools used for rook debugging and testing
toolbox_cmd="kubectl -n rook-ceph-system exec -it $(kubectl -n rook-ceph-system get pod -l 'app=rook-ceph-tools' -o jsonpath='{.items[0].metadata.name}') -- "

$toolbox_cmd rados df
$toolbox_cmd ceph df

# Test
info "===== Test started ====="

assert_contains "$(kubectl get storageclasses --no-headers -o custom-columns=name:.metadata.name)" "rook-ceph-block" "Rook Ceph Block storage class doesn't exist"
assert_are_equal "$(kubectl get storageclasses -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')" "rook-ceph-block" "Rook Ceph Block isn't default storage class"
assert_contains "$($toolbox_cmd ceph health)" "HEALTH_OK" "Ceph clusters is not  OK"
assert_contains "$($toolbox_cmd rados lspools)" "replicapool" "RADOS cluster"

info "===== Test completed ====="
