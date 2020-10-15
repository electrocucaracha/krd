#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
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

katacontainers_deployment_name=kata-demo

# Setup
destroy_deployment "$katacontainers_deployment_name"

# Test
info "===== Test started ====="

info "+++++ Kata Containers QEMU validation:"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1 
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: kata
  name: $katacontainers_deployment_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kata
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kata
    spec:
      runtimeClassName: kata-qemu
      containers:
      - image: k8s.gcr.io/hpa-example
        imagePullPolicy: Always
        name: php-apache
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          requests:
            cpu: 200m
      restartPolicy: Always
EOF
wait_deployment "$katacontainers_deployment_name"
deployment_pod=$(kubectl get pods -l=app.kubernetes.io/name=kata -o jsonpath='{.items[0].metadata.name}')
info "$deployment_pod assertions:"
assert_non_empty "$(kubectl get pods "$deployment_pod" -o jsonpath='{.spec.runtimeClassName}')" "$deployment_pod is using the default runtime"
assert_are_not_equal "$(kubectl exec -it "$deployment_pod" -- uname -a)" "$(uname -a)" "$deployment_pod has the same kernel version than the host"

info "===== Test completed ====="

# Teardown
destroy_deployment "$katacontainers_deployment_name"
