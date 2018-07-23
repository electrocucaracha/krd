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

if [[ -z $(docker images -q generic_sim) ]]; then
    BUILD_ARGS="--no-cache"
    if [ $HTTP_PROXY ]; then
        BUILD_ARGS+=" --build-arg HTTP_PROXY=${HTTP_PROXY}"
    fi
    if [ $HTTPS_PROXY ]; then
        BUILD_ARGS+=" --build-arg HTTPS_PROXY=${HTTPS_PROXY}"
    fi
    pushd generic_simulator
    docker build ${BUILD_ARGS} -t generic_sim:latest .
    popd
fi

if [[ $(docker ps -q --all --filter "name=aai") ]]; then
    docker rm aai -f
fi

docker run --name aai -v $(pwd)/output:/tmp/generic_sim/ -v $(pwd)/generic_simulator/aai/:/etc/generic_sim/ -p 8443:8080 -d generic_sim

curl -X POST http://localhost:8081/v1/vnf_instances -d "{"cloud_region_id": "region1", "csar_id": "uuid", "oof_parameters": [{"key1": "value1", "key2": "value2", "key3": {} }]}"
