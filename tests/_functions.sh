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

# destroy_deployment() - This function ensures that a specific deployment is
# destroyed in Kubernetes
function destroy_deployment {
    local deployment_name=$1

    echo "$(date +%H:%M:%S) - $deployment_name : Destroying deployment"
    kubectl delete deployment "$deployment_name" --ignore-not-found=true --now
    while kubectl get deployment "$deployment_name" &>/dev/null; do
        echo "$(date +%H:%M:%S) - $deployment_name : Destroying deployment"
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

    status_phase=""
    while [[ "$status_phase" != "Running" ]]; do
        new_phase=$(kubectl get pods | grep  "$deployment_name" | awk '{print $3}')
        if [[ "$new_phase" != "$status_phase" ]]; then
            echo "$(date +%H:%M:%S) - $deployment_name : $new_phase"
            status_phase=$new_phase
        fi
        if [[ "$new_phase" == "Err"* ]]; then
            exit 1
        fi
    done
}

# setup() - Base testing setup shared among functional tests
function setup {
    for deployment_name in "$@"; do
        recreate_deployment "$deployment_name"
    done
    sleep 5
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

if ! kubectl version &>/dev/null; then
    echo "This funtional test requires kubectl client"
    exit 1
fi
TEST_FOLDER=$(pwd)
export TEST_FOLDER
