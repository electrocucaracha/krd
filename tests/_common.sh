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

image_name=virtlet.cloud/ubuntu/16.04
multus_deployment_name=multus-deployment
virtlet_image=virtlet.cloud/fedora
virtlet_deployment_name=virtlet-deployment

# populate_CSAR_multus() - This function creates the content of CSAR file
# required for testing Multus feature
function populate_CSAR_multus {
    local csar_id=$1

    _checks_args $csar_id
    pushd ${CSAR_DIR}/${csar_id}

    cat << META > metadata.yaml
resources:
  network:
    - bridge-network.yaml
  deployment:
    - $multus_deployment_name.yaml
META

    cat << NET > bridge-network.yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: bridge-conf
spec:
  config: '{
    "cniVersion": "0.3.0",
    "name": "mynet",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "10.10.0.0/16"
    }
}'
NET

    cat << DEPLOYMENT > $multus_deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $multus_deployment_name
  labels:
    app: multus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multus
  template:
    metadata:
      labels:
        app: multus
      annotations:
        k8s.v1.cni.cncf.io/networks: '[
          { "name": "bridge-conf", "interfaceRequest": "eth1" },
          { "name": "bridge-conf", "interfaceRequest": "eth2" }
        ]'
    spec:
      containers:
      - name: $multus_deployment_name
        image: "busybox"
        command: ["top"]
        stdin: true
        tty: true
DEPLOYMENT
    popd
}

# populate_CSAR_virtlet() - This function creates the content of CSAR file
# required for testing Virtlet feature
function populate_CSAR_virtlet {
    local csar_id=$1

    _checks_args $csar_id
    pushd ${CSAR_DIR}/${csar_id}

    cat << META > metadata.yaml
resources:
  deployment:
    - $virtlet_deployment_name.yaml
META

    cat << DEPLOYMENT > $virtlet_deployment_name.yaml
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
        VirtletLibvirtCPUSetting: |
          mode: host-passthrough
        # This tells CRI Proxy that this pod belongs to Virtlet runtime
        kubernetes.io/target-runtime: virtlet.cloud
        VirtletCloudInitUserData: |
          ssh_pwauth: True
          users:
          - name: testuser
            gecos: User
            primary-group: testuser
            groups: users
            lock_passwd: false
            shell: /bin/bash
            # the password is "testuser"
            passwd: "\$6\$rounds=4096\$wPs4Hz4tfs\$a8ssMnlvH.3GX88yxXKF2cKMlVULsnydoOKgkuStTErTq2dzKZiIx9R/pPWWh5JLxzoZEx7lsSX5T2jW5WISi1"
            sudo: ALL=(ALL) NOPASSWD:ALL
          runcmd:
            - echo hello world
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
            memory: 160Mi
DEPLOYMENT
    popd
}
