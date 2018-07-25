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
pod_name=vfirewall-pod

cat << NET >> $HOME/ovn-network.yaml
apiVersion: "kubernetes.cni.cncf.io/v1"
kind: Network
metadata:
  name: ovn-conf
spec:
  config: '{
    "name":"ovn-kubernetes",
    "type":"ovn-k8s-cni-overlay",
    "ipam": {
        "subnet": "10.11.0.0/16"
    }
}'
NET

cat << POD > $HOME/vFirewall.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  annotations:
    VirtletCloudInitUserDataScript: |
      #!/bin/sh
      echo hello world
    kubernetes.v1.cni.cncf.io/networks: '[
        { "name": "bridge-conf", "interfaceRequest": "eth1" }
    ]'
#    kubernetes.io/target-runtime: virtlet.cloud
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
spec:  # specification of the pod's contents
  containers:
  - name: packetgen
    #image: virtlet.cloud/ubuntu/16.04
    image: "busybox"
    imagePullPolicy: IfNotPresent
    tty: true
    stdin: true
    resources:
      limits:
        # This memory limit is applied to the libvirt domain definition
        memory: 160Mi
POD

if $(kubectl version &>/dev/null); then
    kubectl apply -f $HOME/ovn-network.yaml

    kubectl delete pod $pod_name --ignore-not-found=true --now
    while kubectl get pod $pod_name &>/dev/null; do
        sleep 5
    done
    kubectl create -f $HOME/vFirewall.yaml

    status_phase=""
    while [[ $status_phase != "Running" ]]; do
        new_phase=$(kubectl get pods $pod_name | awk 'NR==2{print $3}')
        if [[ $new_phase != $status_phase ]]; then
            echo "$(date +%H:%M:%S) - $new_phase"
            status_phase=$new_phase
        fi
        if [[ $new_phase == "Err"* ]]; then
            exit 1
        fi
    done

    kubectl exec -it $pod_name -- ip a
    multus_nic=$(kubectl exec -it $pod_name -- ifconfig | grep "eth1")
    if [ -z "$multus_nic" ]; then
        exit 1
    fi
fi
