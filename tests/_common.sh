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

# populate_nfd() - This function creates the content required for testing NFD feature
function populate_nfd {
    local nfd_deployment_name=${1}

    mkdir -p "/tmp/${nfd_deployment_name}"
    pushd "/tmp/${nfd_deployment_name}"

    # editorconfig-checker-disable
    cat <<DEPLOYMENT >"$nfd_deployment_name.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $nfd_deployment_name
  labels:
    app: nfd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfd
  template:
    metadata:
      labels:
        app: nfd
    spec:
      containers:
      - name: $nfd_deployment_name
        image: "busybox"
        command: ["top"]
        stdin: true
        tty: true
      nodeSelector:
        feature.node.kubernetes.io/cpu-cpuid.ADX: "true"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: feature.node.kubernetes.io/kernel-version.major
                operator: Gt
                values: ["2"]
DEPLOYMENT
    # editorconfig-checker-enable
    popd
}

# populate_qat() - This function creates the content required for testing QAT feature
function populate_qat {
    local qat_deployment_name=${1}
    local num_qat_replicas=12
    local qat_dev_name="cy1_dc0"

    mkdir -p "/tmp/${qat_deployment_name}"
    pushd "/tmp/${qat_deployment_name}"

    # editorconfig-checker-disable
    cat <<DEPLOYMENT >"$qat_deployment_name.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${qat_deployment_name}
  labels:
    app: nginx-behind-envoy-qat
spec:
  replicas: ${num_qat_replicas}
  selector:
    matchLabels:
      app: nginx-behind-envoy-qat
  template:
    metadata:
      labels:
        app: nginx-behind-envoy-qat
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          securityContext:
            privileged: true
        - name: envoy-sidecar
          image: envoy-qat:devel
          imagePullPolicy: IfNotPresent
          command:
            - "/envoy-static"
          args:
            - "-c"
            - "/etc/envoy/config/envoy-conf.yaml"
          securityContext:
            privileged: true
          resources:
            limits:
              qat.intel.com/${qat_dev_name}: 1
              cpu: 2
          volumeMounts:
            - name: tls
              mountPath: /etc/envoy/tls
              readOnly: true
            - name: config
              mountPath: /etc/envoy/config
              readOnly: true
      volumes:
        - name: tls
          secret:
            secretName: envoy-tls-secret
        - name: config
          configMap:
            name: envoy-sidecar-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-sidecar-config
data:
  envoy-conf.yaml: |
    static_resources:
      listeners:
      - address:
          socket_address:
            address: 0.0.0.0
            port_value: 9000
        filter_chains:
          tls_context:
            common_tls_context:
              tls_certificates:
                certificate_chain: { "filename": "/etc/envoy/tls/tls.crt" }
                private_key: { "filename": "/etc/envoy/tls/tls.key" }
          filters:
          - name: envoy.http_connection_manager
            config:
              codec_type: auto
              stat_prefix: ingress_http
              route_config:
                name: local_route
                require_ssl: all
                virtual_hosts:
                - name: backend
                  domains:
                  - "*"
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: local_service
              http_filters:
              - name: envoy.router
                config: {}
      clusters:
      - name: local_service
        connect_timeout: 0.25s
        type: STATIC
        lb_policy: round_robin
        hosts:
        - socket_address:
            address: 127.0.0.1
            port_value: 80
    admin:
      access_log_path: "/dev/null"
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 9001
DEPLOYMENT
    # editorconfig-checker-enable
    popd
}
