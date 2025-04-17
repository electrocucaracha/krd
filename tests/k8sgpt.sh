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
    kubectl delete -f resources/broken-pod.yaml
}

# Setup
trap cleanup EXIT

# Test
info "===== Test started ====="
kubectl apply -f resources/broken-pod.yaml

assert_non_empty "$(kubectl get results.core.k8sgpt.ai -n k8sgpt-operator-system defaultbrokenpod)" "K8sGPT didn't generate a result object"

info "===== Test completed ====="
