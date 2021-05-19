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

echo_deployment_name="echo"

function cleanup {
    destroy_deployment "$echo_deployment_name"
    kubectl delete service echo --ignore-not-found
    kubectl delete kongplugin request-id --ignore-not-found
    kubectl delete ingress demo --ignore-not-found
    kubectl delete kongplugin request-id --ignore-not-found
}

trap cleanup EXIT

# Setup
HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
PORT=$(kubectl get svc kong-kong-proxy -o jsonpath='{.spec.ports[0].nodePort}')
CURL_PROXY_CMD="curl -s http://${HOST}:${PORT}"

# Test
info "===== Test started ====="
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: echo
  name: echo
spec:
  ports:
  - port: 8080
    name: high
    protocol: TCP
    targetPort: 8080
  - port: 80
    name: low
    protocol: TCP
    targetPort: 8080
  selector:
    app: echo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: echo
  name: $echo_deployment_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
        - image: gcr.io/kubernetes-e2e-test-images/echoserver:2.2
          name: echo
          ports:
            - containerPort: 8080
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
EOF
wait_deployment "$echo_deployment_name"

assert_non_empty "$($CURL_PROXY_CMD)" "There is no output from Kong's proxy"
assert_contains "$($CURL_PROXY_CMD)" '{"message":"no Route matched with those values"}' "Routes has been defined for this service"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
spec:
  ingressClassName: kong
  rules:
    - http:
        paths:
          - path: /foo
            pathType: Prefix
            backend:
              service:
                name: echo
                port:
                  number: 80
EOF
sleep 5 # TODO: Improve the waiting method
assert_contains "$(eval "$CURL_PROXY_CMD/foo")" "Pod Information:" "The server response doesn't have pod's info"

cat <<EOF | kubectl apply -f -
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: request-id
config:
  header_name: my-request-id
plugin: correlation-id
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo
  annotations:
    konghq.com/plugins: request-id
spec:
  ingressClassName: kong
  rules:
    - host: example.com
      http:
        paths:
          - path: /bar
            pathType: Prefix
            backend:
              service:
                name: echo
                port:
                  number: 80
EOF
sleep 5
assert_contains "$(eval "$CURL_PROXY_CMD/bar/sample -H 'Host: example.com'")" "Pod Information:" "The server response doesn't have pod's info for example.com host"

info "===== Test completed ====="
