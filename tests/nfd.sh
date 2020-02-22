#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
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

nfd_deployment_name=nfd-deployment

# Setup
populate_nfd $nfd_deployment_name
pushd /tmp/${nfd_deployment_name}
setup "$nfd_deployment_name"

if ! command -v jq; then
    curl -fsSL http://bit.ly/install_pkg | PKG=jq bash
fi
kubectl get nodes -o json -l node-role.kubernetes.io/master!= | jq .items[].metadata.labels
labels=$(kubectl get nodes -o jsonpath="{.items[*].metadata.labels}" -l node-role.kubernetes.io/master!=)
if [[ $labels != *"feature.node.kubernetes.io"* ]]; then
    echo "There is no feature discovered in any worker node"
    exit 1
fi

# Teardown
teardown "$nfd_deployment_name"
