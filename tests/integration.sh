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
packetgen_pod_name=packetgen
sink_pod_name=sink
firewall_pod_name=firewall
image_name=virtlet.cloud/ubuntu/16.04

if [[ ! -f $HOME/.ssh/id_rsa.pub ]]; then
    echo -e "\n\n\n" | ssh-keygen -t rsa -N ""
fi
ssh_key=$(cat $HOME/.ssh/id_rsa.pub)

cat << NET >> $HOME/unprotected-private-net-cidr-network.yaml
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

cat << NET >> $HOME/protected-private-net-cidr-network.yaml
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

cat << NET >> $HOME/onap-private-net-cidr-network.yaml
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

proxy="#!/bin/bash"
if [[ -n "${http_proxy+x}" ]]; then
    proxy+="
        export http_proxy=$http_proxy
        echo \"Acquire::http::Proxy \\\"$http_proxy\\\";\" | sudo tee --append /etc/apt/apt.conf.d/01proxy
"
fi
if [[ -n "${https_proxy+x}" ]]; then
    proxy+="
        export https_proxy=$https_proxy
        echo \"Acquire::https::Proxy \\\"$https_proxy\\\";\" | sudo tee --append /etc/apt/apt.conf.d/01proxy
"
fi
if [[ -n "${no_proxy+x}" ]]; then
    proxy+="
        export no_proxy=$no_proxy"
fi

cat << POD > $HOME/$packetgen_pod_name.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $packetgen_pod_name
  annotations:
    VirtletCloudInitUserData: |
      users:
      - default
      - name: admin
        sudo: ALL=(ALL) NOPASSWD:ALL
        plain_text_passwd: secret
        groups: sudo
        ssh_authorized_keys:
          - $ssh_key
    VirtletCloudInitUserDataScript: |
        $proxy

        wget -O - https://raw.githubusercontent.com/electrocucaracha/vFW-demo/master/$packetgen_pod_name | sudo -E bash
    kubernetes.v1.cni.cncf.io/networks: '[
        { "name": "unprotected-private-net-cidr", "interfaceRequest": "eth1" },
        { "name": "onap-private-net-cidr", "interfaceRequest": "eth2" }
    ]'
    kubernetes.io/target-runtime: virtlet.cloud
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
  - name: $packetgen_pod_name
    image: $image_name
    imagePullPolicy: IfNotPresent
    tty: true
    stdin: true
    resources:
      limits:
        memory: 256Mi
POD

cat << POD > $HOME/$firewall_pod_name.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $firewall_pod_name
  annotations:
    VirtletCloudInitUserData: |
      users:
      - default
      - name: admin
        gecos: Administrator User
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - $ssh_key
    VirtletCloudInitUserDataScript: |
        $proxy

        wget -O - https://raw.githubusercontent.com/electrocucaracha/vFW-demo/master/$firewall_pod_name | sudo -E bash
    kubernetes.v1.cni.cncf.io/networks: '[
        { "name": "unprotected-private-net-cidr", "interfaceRequest": "eth1" },
        { "name": "protected-private-net-cidr", "interfaceRequest": "eth2" },
        { "name": "onap-private-net-cidr", "interfaceRequest": "eth3" }
    ]'
    kubernetes.io/target-runtime: virtlet.cloud
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
  - name: $firewall_pod_name
    image: $image_name
    imagePullPolicy: IfNotPresent
    tty: true
    stdin: true
    resources:
      limits:
        memory: 160Mi
POD

cat << POD > $HOME/$sink_pod_name.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $sink_pod_name
  annotations:
    VirtletCloudInitUserData: |
      users:
      - default
      - name: admin
        gecos: Administrator User
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - $ssh_key
    VirtletCloudInitUserDataScript: |
        $proxy

        wget -O - https://raw.githubusercontent.com/electrocucaracha/vFW-demo/master/$sink_pod_name | sudo -E bash
    kubernetes.v1.cni.cncf.io/networks: '[
        { "name": "protected-private-net-cidr", "interfaceRequest": "eth1" },
        { "name": "onap-private-net-cidr", "interfaceRequest": "eth2" }
    ]'
    kubernetes.io/target-runtime: virtlet.cloud
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
  - name: $sink_pod_name
    image: $image_name
    imagePullPolicy: IfNotPresent
    tty: true
    stdin: true
    resources:
      limits:
        memory: 160Mi
POD

if $(kubectl version &>/dev/null); then
    kubectl apply -f $HOME/unprotected-private-net-cidr-network.yaml
    kubectl apply -f $HOME/protected-private-net-cidr-network.yaml
    kubectl apply -f $HOME/onap-private-net-cidr-network.yaml

    for pod_name in $packetgen_pod_name $firewall_pod_name $sink_pod_name; do
        kubectl delete pod $pod_name --ignore-not-found=true --now
        while kubectl get pod $pod_name &>/dev/null; do
            sleep 5
        done
        kubectl create -f $HOME/$pod_name.yaml
    done

    for pod_name in $packetgen_pod_name $firewall_pod_name $sink_pod_name; do
        status_phase=""
        while [[ $status_phase != "Running" ]]; do
            new_phase=$(kubectl get pods $pod_name | awk 'NR==2{print $3}')
            if [[ $new_phase != $status_phase ]]; then
                echo "$(date +%H:%M:%S) - $pod_name : $new_phase"
                status_phase=$new_phase
            fi
            if [[ $new_phase == "Err"* ]]; then
                exit 1
            fi
        done
    done
    for pod_name in $packetgen_pod_name $firewall_pod_name $sink_pod_name; do
        vm=$(kubectl plugin virt virsh list | grep ".*$pod_name"  | awk '{print $2}')
        echo "Pod name: $pod_name Virsh domain: $vm"
        echo "ssh -i ~/.ssh/id_rsa.pub admin@$(kubectl get pods $pod_name -o jsonpath="{.status.podIP}")"
        echo "=== Virtlet details ===="
        echo "$(kubectl plugin virt virsh dumpxml $vm | grep VIRTLET_)\n"
    done
fi
