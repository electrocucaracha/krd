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

# populate_virtlet() - This function creates the content of yaml file
# required for testing Virtlet feature
function populate_virtlet {
    local virtlet_deployment_name=$1
    local virtlet_image="virtlet.cloud/${2:-fedora}"

    mkdir -p "/tmp/${virtlet_deployment_name}"
    pushd "/tmp/${virtlet_deployment_name}"
    if ! command -v mkpasswd; then
        curl -fsSL http://bit.ly/install_pkg | PKG=whois bash
    fi

    proxy="apt:"
    cloud_init_proxy=""
    if [[ -n "${HTTP_PROXY+x}" ]]; then
        proxy+="
            http_proxy: $HTTP_PROXY"
        cloud_init_proxy+="
            - export http_proxy=$HTTP_PROXY
            - export HTTP_PROXY=$HTTP_PROXY"
    fi
    if [[ -n "${HTTPS_PROXY+x}" ]]; then
        proxy+="
            https_proxy: $HTTPS_PROXY"
        cloud_init_proxy+="
            - export https_proxy=$HTTPS_PROXY
            - export HTTPS_PROXY=$HTTPS_PROXY"
    fi
    if [[ -n "${NO_PROXY+x}" ]]; then
        cloud_init_proxy+="
            - export no_proxy=$NO_PROXY
            - export NO_PROXY=$NO_PROXY"
    fi
    cat << DEPLOYMENT > "$virtlet_deployment_name.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $virtlet_deployment_name
  labels:
    app: virtlet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: virtlet
  template:
    metadata:
      labels:
        app: virtlet
      annotations:
        # An optional annotation specifying the count of virtual CPUs.
        # Note that annotation values must always be strings,
        # thus numeric values need to be quoted.
        # Defaults to "1".
        VirtletVCPUCount: "2"
        VirtletLibvirtCPUSetting: |
          mode: host-passthrough
        # This tells CRI Proxy that this pod belongs to Virtlet runtime
        kubernetes.io/target-runtime: virtlet.cloud
        VirtletCloudInitUserData: |
          ssh_pwauth: True
          users:
          - name: demo
            gecos: User
            primary-group: testuser
            groups: users
            lock_passwd: false
            shell: /bin/bash
            # the password is "demo"
            passwd: "$(mkpasswd --method=SHA-512 --rounds=4096 demo)"
            sudo: ALL=(ALL) NOPASSWD:ALL
          $proxy
          runcmd:
          $cloud_init_proxy
            - sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: extraRuntime
                operator: In
                values:
                - virtlet
      containers:
      - name: $virtlet_deployment_name
        # This specifies the image to use.
        # virtlet.cloud/ prefix is used by CRI proxy, the remaining part
        # of the image name is prepended with https:// and used to download the image
        image: $virtlet_image
        imagePullPolicy: IfNotPresent
        # tty and stdin required for "kubectl attach -t" to work
        tty: true
        stdin: true
        resources:
          limits:
            # This memory limit is applied to the libvirt domain definition
            memory: 1Gi
DEPLOYMENT
    popd
}

# populate_nfd() - This function creates the content required for testing NFD feature
function populate_nfd {
    local nfd_deployment_name=${1}

    mkdir -p "/tmp/${nfd_deployment_name}"
    pushd "/tmp/${nfd_deployment_name}"

    cat << DEPLOYMENT > "$nfd_deployment_name.yaml"
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
    popd
}

# populate_qat() - This function creates the content required for testing QAT feature
function populate_qat {
    local qat_deployment_name=${1}
    local num_qat_replicas=12
    local qat_dev_name="cy1_dc0"

    mkdir -p "/tmp/${qat_deployment_name}"
    pushd "/tmp/${qat_deployment_name}"

    cat << DEPLOYMENT > "$qat_deployment_name.yaml"
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
    popd
}
