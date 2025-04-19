#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2025
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
    kubectl delete -f resources/basic-db.yaml
}

# Setup
trap cleanup EXIT

# Test
info "===== Test started ====="
kubectl apply -f resources/basic-db.yaml
sleep 5
cluster_name=$(kubectl get clusters.postgresql.cnpg.io -o jsonpath='{.items[0].metadata.name}')

kubectl wait --for=condition=complete "job/${cluster_name}-1-initdb"
sleep 5
kubectl wait --for=condition=Ready "pod/${cluster_name}-1"

for svc in 'r' ro rw; do
    assert_contains "$(kubectl get services)" "${cluster_name}-$svc" "The ${cluster_name}-$svc service doesn't exist"
done

for secret in app ca replication server; do
    assert_contains "$(kubectl get secrets)" "${cluster_name}-$secret" "The ${cluster_name}-$secret secret doesn't exist"
done

info "===== Test completed ====="
