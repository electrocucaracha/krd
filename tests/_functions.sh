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
if [[ "$KRD_DEBUG" == "true" ]]; then
    set -o xtrace
fi

# info() - This function prints an information message in the standard output
function info {
    _print_msg "INFO" "$1"
}

# error() - This function prints an error message in the standard output
function error {
    _print_msg "ERROR" "$1"
    exit 1
}

function _print_msg {
    echo "$(date +%H:%M:%S) - $1: $2"
}

# assert_non_empty() - This assertion checks if the expected value is not empty
function assert_non_empty {
    local input=$1
    local error_msg=$2

    info "NonEmpty Assertion - value: $1"
    if [ -z "$input" ]; then
        error "$error_msg"
    fi
}

# assert_are_not_equal() - This assertion checks if the inputs are not equal
function assert_are_not_equal {
    local input=$1
    local expected=$2
    local error_msg=$3

    info "Are not equal Assertion - value: $1 expected: $2"
    if [ "$input" == "$expected" ]; then
        error "$error_msg"
    fi
}

# assert_contains() - This assertion checks if the input contains another value
function assert_contains {
    local input=$1
    local expected=$2
    local error_msg=$3

    info "Contains Assertion - value: $1 expected: $2"
    if [[ "$input" != *"$expected"* ]]; then
        error "$error_msg"
    fi
}

# destroy_deployment() - This function ensures that a specific deployment is
# destroyed in Kubernetes
function destroy_deployment {
    local deployment_name=$1

    info "Destroying $deployment_name deployment"
    kubectl delete deployment "$deployment_name" --ignore-not-found=true --now --timeout=5m --wait=true > /dev/null
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

    info "Waiting for $deployment_name deployment..."
    kubectl rollout status "deployment/$deployment_name" --timeout=5m > /dev/null
}

# wait_ingress() - Wait process for IP address asignment on Ingress resources
function wait_ingress {
    local ingress_name=$1
    local attempt_counter=0
    local max_attempts=12

    info "Waiting for $ingress_name ingress..."
    until [ -n "$(kubectl get ingress "$ingress_name" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ]; do
        if [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep 10
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
        kubectl get all -A -o wide
        kubectl get nodes -o wide
    fi
}

# _get_kube_version() - Get the Kubernetes version used or installed on the remote cluster
function _get_kube_version {
    kubectl version -o json | jq -r '.serverVersion.gitVersion'
}
if ! command -v kubectl > /dev/null; then
    echo "This funtional test requires kubectl client"
    exit 1
fi
