#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024
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
    kubectl get pvc,pv
    kubectl delete -f resources/longhorn/
}

trap cleanup EXIT

info "===== Test started ====="

kubectl apply -f resources/longhorn/

kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/pv-claim --timeout=5m
assert_contains "$(kubectl get pv --no-headers)" 'pv-claim' "Persistent volume claim has not bind properly"

info "===== Test completed ====="
