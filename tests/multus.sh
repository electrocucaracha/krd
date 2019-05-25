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

# shellcheck source=tests/_common.sh
source _common.sh
# shellcheck source=tests/_functions.sh
source _functions.sh

multus_deployment_name=multus-deployment

# Setup
populate_CSAR_multus $multus_deployment_name

pushd /tmp/${multus_deployment_name}
kubectl apply -f bridge-network.yaml

setup $multus_deployment_name

# Test
deployment_pod=$(kubectl get pods | grep "$multus_deployment_name" | awk '{print $1}')
echo "===== $deployment_pod details ====="
kubectl exec -it "$deployment_pod" -- ip a
multus_nic=$(kubectl exec -it "$deployment_pod" -- ifconfig | grep "eth1")
if [ -z "$multus_nic" ]; then
    echo "The $deployment_pod pod doesn't contain the eth1 nic"
    exit 1
fi
popd

# Teardown
teardown $multus_deployment_name
