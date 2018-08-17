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

rm -f $HOME/*.yaml

virtlet_image=virtlet.cloud/fedora
pod_name=virtlet-pod
deployment_name=virtlet-deployment

cat << POD > $HOME/$pod_name.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  annotations:
    # This tells CRI Proxy that this pod belongs to Virtlet runtime
    kubernetes.io/target-runtime: virtlet.cloud
    VirtletCloudInitUserDataScript: |
      #!/bin/sh
      echo hello world
spec:
  # This nodeAffinity specification tells Kubernetes to run this
  # pod only on the nodes that have extraRuntime=virtlet label.
  # This label is used by Virtlet DaemonSet to select nodes
  # that must have Virtlet runtime
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
  - name: $pod_name
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
POD

cat << DEPLOYMENT > $HOME/$deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $deployment_name
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
        # This tells CRI Proxy that this pod belongs to Virtlet runtime
        kubernetes.io/target-runtime: virtlet.cloud
        VirtletCloudInitUserDataScript: |
          #!/bin/sh
          echo hello world
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
      - name: $pod_name
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

if $(kubectl version &>/dev/null); then
    kubectl delete pod $pod_name --ignore-not-found=true --now
    kubectl delete deployment $deployment_name --ignore-not-found=true --now
    while kubectl get pod $pod_name &>/dev/null; do
        sleep 5
    done
    kubectl create -f $HOME/$pod_name.yaml
    while kubectl get deployment $deployment_name &>/dev/null; do
        sleep 5
    done
    kubectl create -f $HOME/$deployment_name.yaml
    sleep 5

    deployment_pod=$(kubectl get pods | grep  $deployment_name | awk '{print $1}')
    for pod in $pod_name $deployment_pod; do
        status_phase=""
        while [[ $status_phase != "Running" ]]; do
            new_phase=$(kubectl get pods $pod | awk 'NR==2{print $3}')
            if [[ $new_phase != $status_phase ]]; then
                echo "$(date +%H:%M:%S) - $pod : $new_phase"
                status_phase=$new_phase
            fi
            if [[ $new_phase == "Err"* ]]; then
                exit 1
            fi
        done
    done

    kubectl plugin virt virsh list
    for pod in $pod_name $deployment_pod; do
        virsh_image=$(kubectl plugin virt virsh list | grep "virtlet-.*-$pod")
        if [ -z "$virsh_image" ]; then
            exit 1
        fi
    done

fi
