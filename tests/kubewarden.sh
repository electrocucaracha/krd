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
    kubectl delete clusteradmissionpolicies privileged-pods --ignore-not-found
}

# Setup
cat <<EOF | kubectl apply -f -
apiVersion: policies.kubewarden.io/v1alpha2
kind: ClusterAdmissionPolicy
metadata:
  name: privileged-pods
spec:
  module: registry://ghcr.io/kubewarden/policies/pod-privileged:v0.1.5
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    operations:
    - CREATE
    - UPDATE
  mutating: false
EOF
trap cleanup EXIT
attempt_counter=0
max_attempts=6
until [[ "$(kubectl get clusteradmissionpolicies.policies.kubewarden.io privileged-pods -o jsonpath='{.status.policyStatus}')" == "active" ]]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
        kubectl get clusteradmissionpolicies.policies.kubewarden.io privileged-pods -o yaml
        get_status
        error "Max attempts reached on waiting for privileged-pods Cluster Admission policy"
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep $((attempt_counter * 5))
done

# Test
info "===== Test started ====="

assert_contains "$(kubectl apply -f resources/kubewarden/privileged-pod.yaml 2>&1 || :)" "User 'kubernetes-admin' cannot schedule privileged containers" "Kubewarden didn't restrict the privileged pods creation"

info "===== Test completed ====="
