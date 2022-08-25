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

deployment_name="istio-server"
service_name="istio-server"

function cleanup {
    destroy_deployment "$deployment_name"
    kubectl delete pod client --ignore-not-found --now
    kubectl delete service "$service_name" --ignore-not-found
    kubectl label namespace default istio-injection-
    kubectl delete peerauthentications default --ignore-not-found
}

function create_client {
    local attempt_counter=0
    max_attempts=10

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
spec:
  containers:
    - image: gcr.io/google-samples/istio/loadgen:v0.0.1
      name: main
      env:
        - name: SERVER_ADDR
          value: http://$service_name:80/
        - name: REQUESTS_PER_SECOND
          value: '10'
EOF
    kubectl wait --for=condition=ready pods client --timeout=3m
    kubectl logs -n istio-system -l app=istiod | grep default/client

    info "Waiting for istio's client pod..."
    until [[ "$(kubectl logs client)" == *"10 request(s) complete to http://$service_name:80/"* ]]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            kubectl logs client
            error "Max attempts reached on waiting for istio's client resource"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 2))
    done
}

trap cleanup EXIT

# Setup
kubectl label namespace default istio-injection=enabled --overwrite
kubectl get namespaces --show-labels

# Test https://istiobyexample.dev/mtls/
info "===== Test started ====="

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $deployment_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: server
    spec:
      containers:
      - image: gcr.io/google-samples/istio/helloserver:v0.0.1
        name: main
---
apiVersion: v1
kind: Service
metadata:
  name: $service_name
spec:
  ports:
    - name: http
      port: 80
      targetPort: 8080
  selector:
    app.kubernetes.io/name: server
  type: ClusterIP
EOF
wait_deployment "$deployment_name"
wait_service "$service_name"
create_client

assert_contains "$(kubectl get pods -l=app.kubernetes.io/name=server -o jsonpath='{range .items[0].spec.containers[*]}{.image}{"\n"}{end}')" "istio/proxy" "Istio proxy wasn't injected into the server's pod"

assert_contains "$(kubectl logs client)" "Starting loadgen" "The client's pod doesn't start it"
assert_contains "$(kubectl logs -n istio-system -l app=istiod)" "Sidecar injection request for default/client" "The Client's sidecar injection request wasn't received"

info "===== Test completed ====="
