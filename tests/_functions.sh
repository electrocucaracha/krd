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
if [[ ${KRD_DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

# shellcheck source=tests/_utils.sh
source _utils.sh

# destroy_deployment() - This function ensures that a specific deployment is
# destroyed in Kubernetes
function destroy_deployment {
    local deployment_name=$1
    local attempt_counter=0
    max_attempts=4

    info "Destroying $deployment_name deployment"
    kubectl delete deployment "$deployment_name" --ignore-not-found=true --now --timeout=5m --wait=true >/dev/null
    while [ "$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}' | grep -c "$deployment_name-")" -gt 0 ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            kubectl get pods
            #get_status
            error "Max attempts reached on waiting for $deployment_name deployment resource"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 5))
    done
}

# recreate_deployment() - This function destroys an existing deployment and
# creates an new one based on its yaml file
function recreate_deployment {
    local deployment_name=$1

    destroy_deployment "$deployment_name"
    kubectl create -f "$deployment_name.yaml"
}

# wait_deployment() - Wait process to Running status on the Deployment's pods
function wait_deployment {
    local deployment_name=$1
    local namespace_name=${2:-default}

    info "Waiting for $deployment_name deployment..."
    if ! kubectl rollout status "deployment/$deployment_name" -n "$namespace_name" --timeout=5m >/dev/null; then
        get_status
        error "Timeout reached"
    fi
}

# wait_ingress() - Wait process for IP address asignment on Ingress resources
function wait_ingress {
    local ingress_name=$1
    local attempt_counter=0
    max_attempts=12

    info "Waiting for $ingress_name ingress..."
    until [ -n "$(kubectl get ingress "$ingress_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            kubectl get ingress "$ingress_name" -o yaml
            get_status
            error "Max attempts reached on waiting for $ingress_name ingress resource"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 10))
    done
}

# wait_service() - Wait process for IP address asignment on Service resources
function wait_service {
    local service_name=$1
    local attempt_counter=0
    max_attempts=12

    info "Waiting for $service_name service..."
    until [ -n "$(kubectl get service "$service_name" -o jsonpath='{.spec.clusterIP}')" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            kubectl get service "$service_name" -o yaml
            get_status
            error "Max attempts reached on waiting for $service_name service resource"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 10))
    done

    attempt_counter=0
    info "Waiting for $service_name endpoints..."
    until [ -n "$(kubectl get endpoints "$service_name" -o jsonpath='{.subsets[0].addresses[0].ip}')" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ]; then
            kubectl get endpoints "$service_name" -o yaml
            get_status
            error "Max attempts reached on waiting for $service_name service's endpoint resources"
        fi
        attempt_counter=$((attempt_counter + 1))
        sleep $((attempt_counter * 10))
    done
}

# setup() - Base testing setup shared among functional tests
function setup {
    for deployment_name in "$@"; do
        recreate_deployment "$deployment_name"
    done
    for deployment_name in "$@"; do
        wait_deployment "$deployment_name"
    done
}

# teardown() - Base testing teardown function
function teardown {
    for deployment_name in "$@"; do
        destroy_deployment "$deployment_name"
    done
}

# get_status() - Print the current status of the cluster
function get_status {
    printf "CPU usage: "
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    printf "Memory free(Kb):"
    awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    echo "Environment variables:"
    env | grep "KRD"
    if command -v kubectl; then
        echo "Kubernetes Events:"
        kubectl get events -A --sort-by=".metadata.managedFields[0].time"
        echo "Kubernetes Resources:"
        kubectl get all -A -o wide
        echo "Kubernetes Pods:"
        kubectl describe pods
        echo "Kubernetes Nodes:"
        kubectl describe nodes
    fi
}

# _get_kube_version() - Get the Kubernetes version used or installed on the remote cluster
function _get_kube_version {
    kubectl version -o json | jq -r '.serverVersion.gitVersion'
}
if ! command -v kubectl >/dev/null; then
    error "This functional test requires kubectl client"
fi
