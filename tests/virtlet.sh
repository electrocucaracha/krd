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

virtlet_deployment_name=virtlet-deployment

# Setup
populate_CSAR_virtlet $virtlet_deployment_name

pushd /tmp/${virtlet_deployment_name}

setup "$virtlet_deployment_name"

# Test
deployment_pod=$(kubectl get pods | grep $virtlet_deployment_name | awk '{print $1}')
vm_name=$(kubectl plugin virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $2}')
vm_status=$(kubectl plugin virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $3}')
if [[ "$vm_status" != "running" ]]; then
    echo "There is no Virtual Machine running by $deployment_pod pod"
    exit 1
fi
echo "Pod name: $deployment_pod Virsh domain: $vm_name"
echo "ssh testuser@$(kubectl get pods $deployment_pod -o jsonpath="{.status.podIP}")"
echo "kubectl attach -it $deployment_pod"
echo "=== Virtlet details ===="
printf "$(kubectl plugin virt virsh dumpxml $vm_name | grep VIRTLET_)\n"
popd

# Teardown
teardown "$virtlet_deployment_name"
