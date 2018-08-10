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

base_url="http://localhost:8081/v1/vnf_instances/"
cloud_region_id="krd"
namespace="default"
csar_id="94e414f6-9ca4-11e8-bb6a-52540067263b"

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

vnf_id_list=$(curl -s "${base_url}${cloud_region_id}/${namespace}" | jq -r '.vnf_id_list')

mkdir -p ${CSAR_DIR}/${csar_id}
cat << SEQ > ${CSAR_DIR}/${csar_id}/sequence.yaml
deployment:
  - deployment.yaml
service:
  - service.yaml
SEQ
cat << DEPLOYMENT > ${CSAR_DIR}/${csar_id}/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multus-deployment
  labels:
    app: multus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multus
  template:
    metadata:
      labels:
        app: multus
      annotations:
        kubernetes.v1.cni.cncf.io/networks: '[
          { "name": "bridge-conf", "interfaceRequest": "eth1" },
          { "name": "bridge-conf", "interfaceRequest": "eth2" }
        ]'
    spec:
      containers:
      - name: multus-deployment
        image: "busybox"
        command: ["top"]
        stdin: true
        tty: true
DEPLOYMENT
cat << SERVICE >  ${CSAR_DIR}/${csar_id}/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: sise-svc
spec:
  ports:
  - port: 80
    protocol: TCP
  selector:
    app: sise
SERVICE

payload_raw="
{
    \"cloud_region_id\": \"$cloud_region_id\",
    \"namespace\": \"$namespace\",
    \"csar_id\": \"$csar_id\"
}
"
payload=$(echo $payload_raw | tr '\n' ' ')
curl -v -X POST -d "$payload" "${base_url}"
