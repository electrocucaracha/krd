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
pushd ..
source _installers.sh
popd

qat_deployment_name=qat-deployment

# Setup
eval "ANSIBLE_ROLES_PATH=/tmp/galaxy-roles $ansible_cmd ./configure-envoy.yml"
populate_qat $qat_deployment_name
pushd /tmp/${qat_deployment_name}
if ! kubectl get secret --no-headers | grep -e envoy-tls-secret; then
    openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout key.pem -out cert.pem
    kubectl create secret tls envoy-tls-secret --cert cert.pem --key key.pem
fi
setup "$qat_deployment_name"

# Teardown
teardown "$qat_deployment_name"
