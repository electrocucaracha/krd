#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2026
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o pipefail
set -o nounset

if [[ ${KRD_DEBUG-false} == "true" ]]; then
    set -o xtrace
fi

export KRD_TOPOLVM_VOLUME_GROUP_NAME=csi-vgs
export KRD_ARC_TOKEN="${KRD_ARC_TOKEN:?"Error: KRD_ARC_TOKEN environment variable is required."}"

repos=(
    kubevirt-actions-runner
    bootstrap-vagrant
    k8s-HorizontalPodAutoscaler-demo
    k8s-Ingress-demo
    k8s-KPT-demo
    krd
    lint-devstack
    openstack-multinode
    pkg-mgr_scripts
    releng
    test-arc-repo
    vagrant-boxes
)

github_url="https://github.com/electrocucaracha"

# Cleanup previous installation
./krd_command.sh -a uninstall_k8s
sudo rm -rf /opt/kubespray

for lv in $(sudo lvs --noheadings -o lv_name csi-vgs | awk '{print $1}'); do
    sudo lvremove -y "${KRD_TOPOLVM_VOLUME_GROUP_NAME}/${lv}"
done

./krd_command.sh -a install_k8s
./krd_command.sh -a install_topolvm
# sudo lvcreate -L 200G --type thin-pool -n thin-pool csi-vgs

./krd_command.sh -a install_kubevirt
./krd_command.sh -a install_tekton

kubectl wait --for=condition=available --timeout=10m deployment --all --all-namespaces

# Create Golden Image pipeline
kubectl apply -f resources/ubuntu-runner-pipeline.yml
kubectl apply -f resources/ubuntu-runner-pipelineruns.yml
kubectl wait pipelineruns.tekton.dev/create-ubuntu-jammy-runner --for=condition=Succeeded --timeout=15m
kubectl delete -f resources/ubuntu-runner-pipelineruns.yml

# Get VM template
kubectl apply -f resources/kubevirt-runner/

### Self-Hosted GitHub Actions configuration
for repo in "${repos[@]}"; do
    KRD_ARC_GITHUB_URL="$github_url/$repo" ./krd_command.sh -a install_chart_arc
    sleep 180 # TODO: Remove this sleep until a better approach is implemented
done

# Create Garbage Collectors
kubectl apply -f resources/arc-cleanup.yml
