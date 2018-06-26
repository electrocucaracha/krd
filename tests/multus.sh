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

cat << MULTUSNET01 >> $HOME/flannel-network.yaml
apiVersion: "kubernetes.com/v1"
kind: Network
metadata:
  name: flannel-conf
plugin: flannel
args: '[
        {
                "delegate": {
                        "isDefaultGateway": true
                }
        }
]'
MULTUSNET01

cat << MULTUSNET02 >> $HOME/flannel-network2.yaml
apiVersion: "kubernetes.com/v1"
kind: Network
metadata:
  name: flannel-conf2
plugin: flannel
args: '[
        {
                "delegate": {
                        "isDefaultGateway": true
                }
        }
]'
MULTUSNET02

cat << MULTUSPOD >> $HOME/pod-multi-network.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multus-multi-net-pod
  annotations:
    networks: '[
        { "name": "flannel-conf" },
        { "name": "flannel-conf2" },
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
    kubectl create -f $HOME/flannel-network.yaml
    kubectl create -f $HOME/flannel-network2.yaml
    kubectl create -f $HOME/pod-multi-network.yaml

    #kubectl get pods --all-namespaces -o wide -w

    #kubectl get pod multus-multi-net-pod
fi
