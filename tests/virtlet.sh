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

pod_name=cirros-vm

cat << CIRROSPOD > $HOME/cirros-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  annotations:
    # This tells CRI Proxy that this pod belongs to Virtlet runtime
    kubernetes.io/target-runtime: virtlet.cloud
    # CirrOS doesn't load nocloud data from SCSI CD-ROM for some reason
    VirtletDiskDriver: virtio
    # inject ssh keys via cloud-init
    VirtletSSHKeys: |
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCaJEcFDXEK2ZbX0ZLS1EIYFZRbDAcRfuVjpstSc0De8+sV1aiu+dePxdkuDRwqFtCyk6dEZkssjOkBXtri00MECLkir6FcH3kKOJtbJ6vy3uaJc9w1ERo+wyl6SkAh/+JTJkp7QRXj8oylW5E20LsbnA/dIwWzAF51PPwF7A7FtNg9DnwPqMkxFo1Th/buOMKbP5ZA1mmNNtmzbMpMfJATvVyiv3ccsSJKOiyQr6UG+j7sc/7jMVz5Xk34Vd0l8GwcB0334MchHckmqDB142h/NCWTr8oLakDNvkfC1YneAfAO41hDkUbxPtVBG5M/o7P4fxoqiHEX+ZLfRxDtHB53 me@localhost
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
  - name: cirros-vm
    # This specifies the image to use.
    # virtlet.cloud/ prefix is used by CRI proxy, the remaining part
    # of the image name is prepended with https:// and used to download the image
    image: virtlet.cloud/fedora
    imagePullPolicy: IfNotPresent
    # tty and stdin required for "kubectl attach -t" to work
    tty: true
    stdin: true
    resources:
      limits:
        # This memory limit is applied to the libvirt domain definition
        memory: 160Mi
CIRROSPOD

cat << CIRROSIMAGE > $HOME/cirros-image.yaml
apiVersion: "virtlet.k8s/v1"
kind: VirtletImageMapping
metadata:
  name: cirros
  namespace: kube-system
spec:
  translations:
  - name: cirros
    url: https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
CIRROSIMAGE

if [[ -n "${http_proxy+x}" ]]; then
    cat << CIRROSIMAGE >> $HOME/cirros-image.yaml
  transports:
    "":
      proxy: "$http_proxy"
CIRROSIMAGE
fi

if $(kubectl version &>/dev/null); then
    kubectl apply -f $HOME/cirros-image.yaml

    kubectl delete pod $pod_name --ignore-not-found=true --now
    while kubectl get pod $pod_name &>/dev/null; do
        sleep 5
    done
    kubectl create -f $HOME/cirros-pod.yaml

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

    kubectl plugin virt virsh list
    virsh_image=$(kubectl plugin virt virsh list | grep "virtlet-.*-$pod_name")
    if [ -z "$virsh_image" ]; then
        exit 1
    fi
fi
