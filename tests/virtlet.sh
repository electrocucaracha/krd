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

virtlet_deployment_name=virtlet-deployment

printf "Waiting for Virtlet services..."
kubectl rollout status daemonset/virtlet -n kube-system --timeout=5m

populate_virtlet $virtlet_deployment_name "ubuntu/18.04"
pushd /tmp/${virtlet_deployment_name}
setup "$virtlet_deployment_name"

# Test
deployment_pod=$(kubectl get pods | grep $virtlet_deployment_name | awk '{print $1}')
vm_name=$(kubectl virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $2}')
vm_status=$(kubectl virt virsh list | grep "virtlet-.*-$virtlet_deployment_name" | awk '{print $3}')
if [[ "$vm_status" != "running" ]]; then
    echo "There is no Virtual Machine running by $deployment_pod pod"
    exit 1
fi
echo "Pod name: $deployment_pod Virsh domain: $vm_name"
echo "ssh testuser@$(kubectl get pods "$deployment_pod" -o jsonpath="{.status.podIP}")"
echo "kubectl attach -it $deployment_pod"
printf "=== Virtlet details ====\n%s\n" "$(kubectl virt virsh dumpxml "$vm_name" | grep VIRTLET_)"
popd

printf "Waiting for Cloud Init service to complete..."
while ! kubectl logs "$deployment_pod" | grep "Cloud-init .* finished"; do
    printf "."
    sleep 2
done

kubectl logs "$deployment_pod" > ~/cloud-init.log

# Teardown
teardown "$virtlet_deployment_name"
