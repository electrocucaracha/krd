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
#set -o xtrace

source _common.sh
source _functions.sh

base_url="http://localhost:8081/v1/vnf_instances/"
cloud_region_id="krd"
namespace="default"
csar_id="94e414f6-9ca4-11e8-bb6a-52540067263b"

# _build_generic_sim() - Creates a generic simulator image in case that doesn't exist
function _build_generic_sim {
    if [[ -n $(docker images -q generic_sim) ]]; then
        return
    fi
    BUILD_ARGS="--no-cache"
    if [ $HTTP_PROXY ]; then
        BUILD_ARGS+=" --build-arg HTTP_PROXY=${HTTP_PROXY}"
    fi
    if [ $HTTPS_PROXY ]; then
        BUILD_ARGS+=" --build-arg HTTPS_PROXY=${HTTPS_PROXY}"
    fi

    pushd generic_simulator
    echo "Building generic simulator image..."
    docker build ${BUILD_ARGS} -t generic_sim:latest .
    popd
}

# start_aai_service() - Starts a simulator for AAI service
function start_aai_service {
    _build_generic_sim
    if [[ $(docker ps -q --all --filter "name=aai") ]]; then
        docker rm aai -f
    fi
    echo "Start AAI simulator.."
    docker run --name aai -v $(mktemp):/tmp/generic_sim/ -v $(pwd)/generic_simulator/aai/:/etc/generic_sim/ -p 8443:8080 -d generic_sim
}

# Setup
destroy_deployment $plugin_deployment_name

#start_aai_service
populate_CSAR_plugin $csar_id

# Test
payload_raw="
{
    \"cloud_region_id\": \"$cloud_region_id\",
    \"namespace\": \"$namespace\",
    \"csar_id\": \"$csar_id\"
}
"
payload=$(echo $payload_raw | tr '\n' ' ')
echo "Creating VNF Instance"
vnf_id=$(curl -s -d "$payload" "${base_url}" | jq -r '.vnf_id')
echo "=== Validating Kubernetes ==="
kubectl get --no-headers=true --namespace=${namespace} deployment ${cloud_region_id}-${namespace}-${vnf_id}-${plugin_deployment_name}
kubectl get --no-headers=true --namespace=${namespace} service ${cloud_region_id}-${namespace}-${vnf_id}-${plugin_service_name}
echo "VNF Instance created succesfully with id: $vnf_id"

vnf_id_list=$(curl -s -X GET "${base_url}${cloud_region_id}/${namespace}" | jq -r '.vnf_id_list')
if [[ "$vnf_id_list" != *"${vnf_id}"* ]]; then
    echo $vnf_id_list
    echo "VNF Instance not stored"
    exit 1
fi

vnf_details=$(curl -s -X GET "${base_url}${cloud_region_id}/${namespace}/${vnf_id}")
if [[ -z "$vnf_details" ]]; then
    echo "Cannot retrieved VNF Instance details"
    exit 1
fi
echo "VNF details $vnf_details"

echo "Deleting $vnf_id VNF Instance"
curl -X DELETE "${base_url}${cloud_region_id}/${namespace}/${vnf_id}"
if [[ -n $(curl -s -X GET "${base_url}${cloud_region_id}/${namespace}/${vnf_id}") ]]; then
    echo "VNF Instance not deleted"
    exit 1
fi

# Teardown
teardown $plugin_deployment_name
