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
set -o pipefail

source _commons.sh

# uninstall_k8s() - Uninstall Kubernetes deployment
function uninstall_k8s {
    sudo ansible-playbook "$verbose" -i "$krd_inventory" "$kubespray_folder/reset.yml" --become | tee "destroy-kubernetes.log"
}

# add_k8s_nodes() - Add Kubernetes worker, master or etcd nodes to the existing cluster
function add_k8s_nodes {
    sudo ansible-playbook "$verbose" -i "$krd_inventory" "$kubespray_folder/scale.yml" --become | tee "destroy-kubernetes.log"
}
