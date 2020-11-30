#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2020
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o pipefail
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi

source _commons.sh

# uninstall_k8s() - Uninstall Kubernetes cluster
function uninstall_k8s {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/reset.yml --extra-vars \"reset_confirmation=yes\"" "destroy-kubernetes.log"
    rm -rf "$kubespray_folder"
}
