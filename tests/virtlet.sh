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

virtlet_deployment_name=virtlet-deployment

function cleanup {
    destroy_deployment "$virtlet_deployment_name"
}

function create_deployment {
    local virtlet_deployment_name=$1
    local virtlet_image="virtlet.cloud/${2:-fedora}"

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
    cat <<EOF | kubectl apply -f -
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
EOF
    wait_deployment "$virtlet_deployment_name"
}

trap cleanup EXIT
trap get_status ERR

info "Waiting for Virtlet services..."
kubectl rollout status daemonset/virtlet -n kube-system --timeout=5m

# Setup
create_deployment "$virtlet_deployment_name" "ubuntu/18.04"

# Test
info "===== Test started ====="

deployment_pod=$(kubectl get pods | grep "$virtlet_deployment_name" | awk '{print $1}')
vm_name=$(kubectl virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $2}')
echo "Pod name: $deployment_pod Virsh domain: $vm_name"
echo "ssh testuser@$(kubectl get pods "$deployment_pod" -o jsonpath="{.status.podIP}")"
echo "kubectl attach -it $deployment_pod"
printf "=== Virtlet details ====\n%s\n" "$(kubectl virt virsh dumpxml "$vm_name" | grep VIRTLET_)"
assert_are_equal "$(kubectl virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $3}')" "running" "There is no Virtual Machine running by $deployment_pod pod"

info "===== Test completed ====="
