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

apache_pod_name=apachetwin
nginx_pod_name=nginxtwin

cat << APACHEPOD > "$HOME/apache-pod.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: $apache_pod_name
  labels:
    name: webserver
spec:
  containers:
  - name: apachetwin
    image: "busybox"
    command: ["top"]
    stdin: true
    tty: true
APACHEPOD

cat << NGINXPOD > "$HOME/nginx-pod.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: $nginx_pod_name
  labels:
    name: webserver
spec:
  containers:
  - name: nginxtwin
    image: "busybox"
    command: ["top"]
    stdin: true
    tty: true
NGINXPOD

cat << APACHEEW > "$HOME/apache-e-w.yaml"
apiVersion: v1
kind: Service
metadata:
  labels:
    name: apacheservice
    role: service
  name: apacheservice
spec:
  ports:
    - port: 8800
      targetPort: 80
      protocol: TCP
      name: tcp
  selector:
    name: webserver
APACHEEW

cat << APACHENS > "$HOME/apache-n-s.yaml"
apiVersion: v1
kind: Service
metadata:
  labels:
    name: apacheexternal
    role: service
  name: apacheexternal
spec:
  ports:
    - port: 8800
      targetPort: 80
      protocol: TCP
      name: tcp
  selector:
    name: webserver
  type: NodePort
APACHENS

if kubectl version &>/dev/null; then
    kubectl apply -f "$HOME/apache-e-w.yaml"
    kubectl apply -f "$HOME/apache-n-s.yaml"

    kubectl delete pod $apache_pod_name --ignore-not-found=true --now
    kubectl delete pod "$nginx_pod_name" --ignore-not-found=true --now
    while kubectl get pod "$apache_pod_name" &>/dev/null; do
        sleep 5
    done
    while kubectl get pod "$nginx_pod_name" &>/dev/null; do
        sleep 5
    done
    kubectl create -f "$HOME/apache-pod.yaml"
    kubectl create -f "$HOME/nginx-pod.yaml"

    status_phase=""
    while [[ $status_phase != "Running" ]]; do
        new_phase=$(kubectl get pods $apache_pod_name | awk 'NR==2{print $3}')
        if [[ "$new_phase" != "$status_phase" ]]; then
            echo "$(date +%H:%M:%S) - $new_phase"
            status_phase=$new_phase
        fi
        if [[ "$new_phase" == "Err"* ]]; then
            exit 1
        fi
    done
    status_phase=""
    while [[ "$status_phase" != "Running" ]]; do
        new_phase=$(kubectl get pods $nginx_pod_name | awk 'NR==2{print $3}')
        if [[ "$new_phase" != "$status_phase" ]]; then
            echo "$(date +%H:%M:%S) - $new_phase"
            status_phase=$new_phase
        fi
        if [[ "$new_phase" == "Err"* ]]; then
            exit 1
        fi
    done
    apache_ovn=$(kubectl get pod $apache_pod_name -o jsonpath="{.metadata.annotations.ovn}")
    nginx_ovn=$(kubectl get pod $nginx_pod_name -o jsonpath="{.metadata.annotations.ovn}")

    echo "$apache_ovn"
    if [[ $apache_ovn != *"\"ip_address\":\"11.11."* ]]; then
        exit 1
    fi

    echo "$nginx_ovn"
    if [[ $nginx_ovn != *"\"ip_address\":\"11.11."* ]]; then
        exit 1
    fi
fi
