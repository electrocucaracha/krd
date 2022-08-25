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
    kubectl delete -f resources/gatekeeper
    kubectl delete namespace opa-test
}

# Setup
kubectl apply -f resources/gatekeeper/template.yml
sleep 5
kubectl apply -f resources/gatekeeper/lb-constraint.yml
if ! kubectl get namespaces/opa-test --no-headers -o custom-columns=name:.metadata.name; then
    kubectl create namespace opa-test
fi
trap cleanup EXIT

# Test
info "===== Test started ====="

cat <<EOF >/tmp/restricted.yaml
kind: Service
apiVersion: v1
metadata:
  name: lb-service
  namespace: opa-test
spec:
  type: LoadBalancer
  selector:
    app: opa-test
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
EOF

assert_contains "$(kubectl apply -f /tmp/restricted.yaml 2>&1 || :)" "Service type LoadBalancer are restricted" "OPA Gatekeeper didn't restrict the service creation using LoadBalancer type"

info "===== Test completed ====="
