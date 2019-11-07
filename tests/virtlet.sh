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

# Setup
if ! command -v helm; then
    pushd ..
    source _installers.sh
    popd
    install_helm
fi
if ! helm ls | grep -e metrics-server; then
    helm install stable/metrics-server --set args[0]="--kubelet-insecure-tls" --set args[1]="--kubelet-preferred-address-types=InternalIP" --name metrics-server
fi

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

printf "Waiting for Cloud Init service to start CPU stress test..."
while ! kubectl logs "$deployment_pod" | grep "Running - CPU stress test"; do
    printf "."
    sleep 2
done

kubectl virt virsh domstats "$vm_name" > ~/domstats_before_suspend.txt
#kubectl top nodes > ~/top_before_suspend.txt
kubectl virt virsh suspend "$vm_name"
printf "Waiting for suspending the %s ..." "$vm_name"
while ! kubectl virt virsh domstate "$vm_name" | grep "paused"; do
    printf "."
    sleep 2
done
#kubectl top nodes > ~/top_after_suspend.txt
kubectl virt virsh domstats "$vm_name" > ~/domstats_after_suspend.txt
kubectl virt virsh resume "$vm_name"

while ! kubectl logs "$deployment_pod" | grep "Cloud-init .* finished"; do
    printf "."
    sleep 2
done
kubectl logs "$deployment_pod" > ~/cloud-init.log

# Teardown
teardown "$virtlet_deployment_name"
