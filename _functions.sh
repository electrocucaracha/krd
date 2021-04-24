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
set -o nounset

source _commons.sh
if [[ "$KRD_DEBUG" == "true" ]]; then
    set -o xtrace
fi

# add_k8s_nodes() - Add Kubernetes worker, master or etcd nodes to the existing cluster
function add_k8s_nodes {
    _install_kubespray
    _run_ansible_cmd "$kubespray_folder/scale.yml" "scale-kubernetes.log"
}

# upgrade_k8s() - Function that graceful upgrades the Kubernetes cluster
function upgrade_k8s {
    kube_version=$(_get_kube_version)
    pushd "$kubespray_folder"
    kubespray_version=$(git describe --tags)
    popd

    if _vercmp "${kube_version#*v}" '==' "${KRD_KUBE_VERSION#*v}"; then
        echo "The kubespray instance has been deployed using the $kube_version version"
        return
    fi

    if [ -n "${KRD_KUBESPRAY_VERSION+x}" ] && _vercmp "${kubespray_version#*v}" '<' "${KRD_KUBESPRAY_VERSION#*v}" ; then
        sed -i "s/^kubespray_version: .*\$/kubespray_version: $KRD_KUBESPRAY_VERSION/" "$krd_playbooks/krd-vars.yml"
        pushd "$kubespray_folder"
        git checkout master
        git pull origin master
        git checkout -b "$KRD_KUBESPRAY_VERSION" "$KRD_KUBESPRAY_VERSION"
        PIP_CMD="sudo -E $(command -v pip) install --no-cache-dir"
        $PIP_CMD -r ./requirements.txt
        popd
    fi
    sed -i "s/^kube_version: .*\$/kube_version: $KRD_KUBE_VERSION/" "$krd_inventory_folder/group_vars/k8s-cluster.yml"
    _run_ansible_cmd "$kubespray_folder/upgrade-cluster.yml" "upgrade-cluster-kubernetes.log"

    sudo cp "$krd_inventory_folder/artifacts/admin.conf" "$HOME/.kube/config"
    sudo chown "$USER" "$HOME/.kube/config"
}

# run_k8s_iperf() - Function that execute networking benchmark
function run_k8s_iperf {
    cat << EOL | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-server-deployment
  labels:
    app: iperf3-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-server
  template:
    metadata:
      labels:
        app: iperf3-server
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/master
                    operator: Exists
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      containers:
        - name: iperf3-server
          image: networkstatic/iperf3
          args: ['-s']
          ports:
            - containerPort: 5201
              name: server
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-server
spec:
  selector:
    app: iperf3-server
  ports:
    - protocol: TCP
      port: 5201
      targetPort: server
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: iperf3-clients
  labels:
    app: iperf3-client
spec:
  selector:
    matchLabels:
      app: iperf3-client
  template:
    metadata:
      labels:
        app: iperf3-client
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/master
                    operator: DoesNotExist
      containers:
        - name: iperf3-client
          image: networkstatic/iperf3
          command: ['/bin/sh', '-c', 'sleep infinity']
EOL
    # Wait for stabilization
    kubectl rollout status daemonset/iperf3-clients --timeout=3m
    kubectl rollout status deployment/iperf3-server-deployment --timeout=3m

    # Perform bechmarking
    kubectl get nodes -o wide | tee  "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
    kubectl get pods -o wide | tee --append  "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
    for pod in $(kubectl get pods -l app=iperf3-client -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
        ip=$(kubectl get pod "$pod" -o jsonpath='{.status.hostIP}')
        bash -c "kubectl exec -it $pod -- iperf3 -c iperf3-server -T \"Client on $ip\"" | tee --append "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
    done

    # Clean up
    kubectl delete deployment/iperf3-server-deployment --ignore-not-found
    kubectl delete service/iperf3-server --ignore-not-found
    kubectl delete daemonset/iperf3-clients --ignore-not-found
}

# wait_for_pods() - Function that waits for the running state
function wait_for_pods {
    local namespace=$1
    local timeout=${2:-900}

    end=$(date +%s)
    end=$((end + timeout))
    PENDING=True
    READY=False
    JOBR=False

    printf "Waiting for %s's pods..." "$namespace"
    until [ $PENDING == "False" ] && [ $READY == "True" ] && [ $JOBR == "True" ]; do
        printf "."
        sleep 5
        kubectl get pods -n "$namespace" -o jsonpath="{.items[*].status.phase}" | grep Pending > /dev/null && PENDING="True" || PENDING="False"
        query='.items[]|select(.status.phase=="Running")'
        query="$query|.status.containerStatuses[].ready"

        kubectl get pods -n "$namespace" -o json | jq -r "$query" | grep false > /dev/null && READY="False" || READY="True"
        kubectl get jobs -n "$namespace" -o json | jq -r '.items[] | .spec.completions == .status.succeeded' | grep false > /dev/null && JOBR="False" || JOBR="True"
        if [ "$(date +%s)" -gt $end ] ; then
            printf "Containers failed to start after %s seconds\n" "$timeout"
            kubectl get pods -n "$namespace" -o wide
            echo
            if [ $PENDING == "True" ] ; then
                echo "Some pods are in pending state:"
                kubectl get pods --field-selector=status.phase=Pending -n "$namespace" -o wide
            fi
            [ $READY == "False" ] && echo "Some pods are not ready"
            [ $JOBR == "False" ] && echo "Some jobs have not succeeded"
            exit
        fi
    done
}
