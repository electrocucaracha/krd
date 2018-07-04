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

cat << MULTUSPOD > $HOME/pod-multi-network.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multus-multi-net-pod
  annotations:
    networks: '[
        { "name": "flannel-conf" },
        { "name": "bridge-conf" }
    ]'
spec:  # specification of the pod's contents
  containers:
  - name: multus-multi-net-pod
    image: "busybox"
    command: ["top"]
    stdin: true
    tty: true
MULTUSPOD

if $(kubectl version &>/dev/null); then
    pod_name=multus-multi-net-pod
    kubectl delete pod $pod_name --ignore-not-found=true --now
    sleep 10
    kubectl create -f $HOME/pod-multi-network.yaml

    status_phase=""
    while [[ $status_phase != "Running" ]]; do
        status_phase=$(kubectl get pods $pod_name -o jsonpath --template={.status.phase})
        sleep 1
    done

    multus_nic=$(kubectl exec -it $pod_name -- ifconfig | grep "net0")
    if [ -z "$multus_nic" ]; then
        exit 1
    fi
fi
