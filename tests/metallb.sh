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

function cleanup {
    kubectl delete service nginx --ignore-not-found
}

trap cleanup EXIT

# Setup

# Test
info "===== Test started ====="

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
EOF

assert_non_empty "$(kubectl get svc nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" "IP address wasn't assigned to nginx service"

info "===== Test completed ====="
