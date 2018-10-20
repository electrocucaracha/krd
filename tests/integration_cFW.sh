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

source _common.sh
source _functions.sh

csar_id=4f726e2a-b74a-11e8-ad7c-525400feed2

# Setup
popule_CSAR_containers_vFW $csar_id

pushd ${CSAR_DIR}/${csar_id}
for network in unprotected-private-net-cidr-network protected-private-net-cidr-network onap-private-net-cidr-network; do
    kubectl apply -f $network.yaml
done
setup $packetgen_deployment_name $firewall_deployment_name $sink_deployment_name

# Test
popd

# Teardown
teardown $packetgen_deployment_name $firewall_deployment_name $sink_deployment_name
