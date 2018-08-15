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

pod_name=multus-pod
deployment_name=multus-deployment

cat << NET > $HOME/bridge-network.yaml
apiVersion: "kubernetes.cni.cncf.io/v1"
kind: Network
metadata:
  name: bridge-conf
spec:
  config: '{
    "name": "mynet",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "10.10.0.0/16"
    }
}'
NET

cat << POD > $HOME/$pod_name.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  annotations:
    kubernetes.v1.cni.cncf.io/networks: '[
      { "name": "bridge-conf", "interfaceRequest": "eth1" },
      { "name": "bridge-conf", "interfaceRequest": "eth2" }
    ]'
spec:  # specification of the pod's contents
  containers:
  - name: $pod_name
    image: "busybox"
    command: ["top"]
    stdin: true
    tty: true
POD

cat << DEPLOYMENT > $HOME/$deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $deployment_name
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
        kubernetes.v1.cni.cncf.io/networks: '[
          { "name": "bridge-conf", "interfaceRequest": "eth1" },
          { "name": "bridge-conf", "interfaceRequest": "eth2" }
        ]'
    spec:
      containers:
      - name: $deployment_name
        image: "busybox"
        command: ["top"]
        stdin: true
        tty: true
DEPLOYMENT

if $(kubectl version &>/dev/null); then
    kubectl apply -f $HOME/bridge-network.yaml

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

    for pod in $pod_name $deployment_pod; do
        echo "===== $pod details ====="
        kubectl exec -it $pod -- ip a
        multus_nic=$(kubectl exec -it $pod -- ifconfig | grep "eth1")
        if [ -z "$multus_nic" ]; then
            exit 1
        fi
    done
fi
