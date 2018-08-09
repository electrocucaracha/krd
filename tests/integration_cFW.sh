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
packetgen_deployment_name=packetgen
sink_deployment_name=sink
firewall_deployment_name=firewall

cat << NET > $HOME/unprotected-private-net-cidr-network.yaml
apiVersion: "kubernetes.cni.cncf.io/v1"
kind: Network
metadata:
  name: unprotected-private-net-cidr
spec:
  config: '{
    "name": "unprotected",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "192.168.10.0/24"
    }
}'
NET

cat << NET > $HOME/protected-private-net-cidr-network.yaml
apiVersion: "kubernetes.cni.cncf.io/v1"
kind: Network
metadata:
  name: protected-private-net-cidr
spec:
  config: '{
    "name": "protected",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "192.168.20.0/24"
    }
}'
NET

cat << NET > $HOME/onap-private-net-cidr-network.yaml
apiVersion: "kubernetes.cni.cncf.io/v1"
kind: Network
metadata:
  name: onap-private-net-cidr
spec:
  config: '{
    "name": "onap",
    "type": "bridge",
    "ipam": {
        "type": "host-local",
        "subnet": "10.10.0.0/16"
    }
}'
NET

cat << DEPLOYMENT > $HOME/$packetgen_deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $packetgen_deployment_name
  labels:
    app: vFirewall
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vFirewall
  template:
    metadata:
      labels:
        app: vFirewall
      annotations:
        kubernetes.v1.cni.cncf.io/networks: '[
            { "name": "unprotected-private-net-cidr", "interfaceRequest": "eth1" },
            { "name": "onap-private-net-cidr", "interfaceRequest": "eth2" }
        ]'
    spec:
      containers:
      - name: $packetgen_deployment_name
        image: electrocucaracha/packetgen
        imagePullPolicy: IfNotPresent
        tty: true
        stdin: true
        resources:
          limits:
            memory: 256Mi
DEPLOYMENT

cat << DEPLOYMENT > $HOME/$firewall_deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $firewall_deployment_name
  labels:
    app: vFirewall
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vFirewall
  template:
    metadata:
      labels:
        app: vFirewall
      annotations:
        kubernetes.v1.cni.cncf.io/networks: '[
            { "name": "unprotected-private-net-cidr", "interfaceRequest": "eth1" },
            { "name": "protected-private-net-cidr", "interfaceRequest": "eth2" },
            { "name": "onap-private-net-cidr", "interfaceRequest": "eth3" }
        ]'
    spec:
      containers:
      - name: $firewall_deployment_name
        image: electrocucaracha/firewall
        imagePullPolicy: IfNotPresent
        tty: true
        stdin: true
        resources:
          limits:
            memory: 160Mi
DEPLOYMENT

cat << DEPLOYMENT > $HOME/$sink_deployment_name.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $sink_deployment_name
  labels:
    app: vFirewall
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vFirewall
  template:
    metadata:
      labels:
        app: vFirewall
      annotations:
        kubernetes.v1.cni.cncf.io/networks: '[
            { "name": "protected-private-net-cidr", "interfaceRequest": "eth1" },
            { "name": "onap-private-net-cidr", "interfaceRequest": "eth2" }
        ]'
    spec:
      containers:
      - name: $sink_deployment_name
        image: electrocucaracha/sink
        imagePullPolicy: IfNotPresent
        tty: true
        stdin: true
        resources:
          limits:
            memory: 160Mi
DEPLOYMENT

if $(kubectl version &>/dev/null); then
    kubectl apply -f $HOME/unprotected-private-net-cidr-network.yaml
    kubectl apply -f $HOME/protected-private-net-cidr-network.yaml
    kubectl apply -f $HOME/onap-private-net-cidr-network.yaml

    for deployment_name in $packetgen_deployment_name $firewall_deployment_name $sink_deployment_name; do
        kubectl delete deployment $deployment_name --ignore-not-found=true --now
        while kubectl get pod $deployment_name &>/dev/null; do
            sleep 5
        done
        kubectl create -f $HOME/$deployment_name.yaml
    done

    for deployment_name in $packetgen_deployment_name $firewall_deployment_name $sink_deployment_name; do
        status_phase=""
        while [[ $status_phase != "Running" ]]; do
            new_phase=$(kubectl get pods | grep  $deployment_name | awk '{print $3}')
            if [[ $new_phase != $status_phase ]]; then
                echo "$(date +%H:%M:%S) - $deployment_name : $new_phase"
                status_phase=$new_phase
            fi
            if [[ $new_phase == "Err"* ]]; then
                exit 1
            fi
        done
    done
fi
