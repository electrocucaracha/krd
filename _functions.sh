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
if [[ $KRD_DEBUG == "true" ]]; then
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

    if [ -n "${KRD_KUBESPRAY_VERSION+x}" ] && _vercmp "${kubespray_version#*v}" '<' "${KRD_KUBESPRAY_VERSION#*v}"; then
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
    # Create resources
    if ! kubectl get namespaces/iperf3 --no-headers -o custom-columns=name:.metadata.name; then
        kubectl create namespace iperf3
    fi
    trap '_delete_namespace iperf3' RETURN
    kubectl apply -f resources/iperf.yml

    # Wait for stabilization
    wait_for_pods iperf3

    # Perform bechmarking
    kubectl get nodes -o wide | tee "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
    kubectl get pods -n iperf3 -o wide | tee --append "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
    for pod in $(kubectl get pods -n iperf3 -l app=iperf3-client -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
        ip=$(kubectl get pod "$pod" -n iperf3 -o jsonpath='{.status.hostIP}')
        hostname=$(kubectl get nodes -o jsonpath="{range .items[?(@.status.addresses[0].address == \"$ip\")]}{.metadata.name}{end}")
        bash -c "kubectl exec -i $pod -n iperf3 -- bash -c 'iperf3 -V -c \$IPERF3_SERVER_SERVICE_HOST -4 --connect-timeout 10 -p 5201 -T \"Client on $hostname\"' ||:" | tee --append "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
        kubectl logs -n iperf3 -l app=iperf3-server | tee --append "$HOME/iperf3-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}.log"
        sleep 10
    done
}

function _setup_demo_app {
    local namespace=$1

    # Create resources
    if ! kubectl get "namespaces/$namespace" --no-headers -o custom-columns=name:.metadata.name; then
        kubectl create namespace "$namespace"
    fi
    kubectl apply -f resources/demo_app.yml -n "$namespace"

    # Wait for stabilization
    wait_for_pods "$namespace"
}

# run_internal_k6() - Function that execute performance HTTP benchmark from the cluster
function run_internal_k6 {
    # Setup
    _setup_demo_app k6
    trap '_delete_namespace k6' RETURN
    kubectl apply -f resources/k6.yml -n k6
    kubectl wait --for=condition=complete job client -n k6 --timeout=3m

    # Collecting results
    pod_name=$(kubectl get pods -l=job-name=client -o jsonpath='{.items[0].metadata.name}' -n k6)
    kubectl get nodes -o wide | tee "$HOME/k6-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}-${KRD_KUBE_PROXY_SCHEDULER}.log"
    kubectl get deployments/http-server-deployment -n k6 -o wide | tee --append "$HOME/k6-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}-${KRD_KUBE_PROXY_SCHEDULER}.log"
    kubectl logs -n k6 "$pod_name" | tail -n 19 | tee --append "$HOME/k6-${KRD_NETWORK_PLUGIN}-${KRD_KUBE_PROXY_MODE}-${KRD_KUBE_PROXY_SCHEDULER}.log"
}

# run_external_k6() - Function that execute performance HTTP benchmark to the cluster
function run_external_k6 {
    install_metallb

    # Setup
    _setup_demo_app k6
    trap '_delete_namespace k6' RETURN
    KUBE_EDITOR='sed -i "s|  type\: .*|  type\: LoadBalancer|g"' kubectl edit svc test -n k6
    until [ -n "$(kubectl get service test -o jsonpath='{.status.loadBalancer.ingress[0].ip}' -n k6)" ]; do
        sleep 1
    done

    # Perform bechmarking
    docker rm k6 || :
    pushd "$(mktemp -d)" >/dev/null
    cat <<EOF >script.js
    import http from "k6/http";
    import { check, sleep } from "k6";
    export let options = {
      vus: 500,
      noConnectionReuse: true,
      duration: "1m"
    };
    export default function() {
      let params = {
        headers: { 'Host': 'test.krd.com' },
      };
      let res = http.get('http://$(kubectl get svc -n k6 test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')', params);
      check(res, {
        "status was 200": (r) => r.status == 200,
        "transaction time OK": (r) => r.timings.duration < 200
      });
    };
EOF
    docker run --name k6 -i loadimpact/k6 run - <script.js
    popd >/dev/null

    # Collecting results
    default_ingress_class="$(kubectl get ingressclasses.networking.k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations}{"\n"}{end}' | grep '"ingressclass.kubernetes.io/is-default-class":"true"' | awk '{ print $1}')"
    kubectl get nodes -o wide | tee "$HOME/k6-${default_ingress_class}.log"
    kubectl get deployments/http-server-deployment -n k6 -o wide | tee --append "$HOME/k6-${default_ingress_class}.log"
    docker logs k6 | tail -n 19 | tee --append "$HOME/k6-${default_ingress_class}.log"
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
        kubectl get pods -n "$namespace" -o jsonpath="{.items[*].status.phase}" | grep Pending >/dev/null && PENDING="True" || PENDING="False"
        query='.items[]|select(.status.phase=="Running")'
        query="$query|.status.containerStatuses[].ready"

        kubectl get pods -n "$namespace" -o json | jq -r "$query" | grep false >/dev/null && READY="False" || READY="True"
        kubectl get jobs -n "$namespace" -o json | jq -r '.items[] | .spec.completions == .status.succeeded' | grep false >/dev/null && JOBR="False" || JOBR="True"
        if [ "$(date +%s)" -gt $end ]; then
            printf "Containers failed to start after %s seconds\n" "$timeout"
            kubectl get pods -n "$namespace" -o wide
            echo
            if [ $PENDING == "True" ]; then
                echo "Some pods are in pending state:"
                kubectl get pods --field-selector=status.phase=Pending -n "$namespace" -o wide
            fi
            [ $READY == "False" ] && echo "Some pods are not ready"
            [ $JOBR == "False" ] && echo "Some jobs have not succeeded"
            exit
        fi
    done
}

# run_kubescape() - Installs and runs Kubescape tool for verifying Kubernetes deployments
function run_kubescape {
    if ! command -v kubescape >/dev/null; then
        curl -s https://raw.githubusercontent.com/armosec/kubescape/master/install.sh | bash
    fi
    kubescape scan framework nsa --exclude-namespaces kube-system,kube-public --silent
}

# run_sonobuoy - Installs and runs Sonobuoy conformance tool
function run_sonobuoy {
    version=$(_get_version sonobuoy)

    if ! command -v sonobuoy >/dev/null; then
        pushd "$(mktemp -d)" >/dev/null
        curl -L -o sonobuoy.tgz "https://github.com/vmware-tanzu/sonobuoy/releases/download/v$version/sonobuoy_${version}_$(uname | awk '{print tolower($0)}')_$(get_cpu_arch).tar.gz" >/dev/null
        tar xzf sonobuoy.tgz
        sudo mv sonobuoy /usr/local/bin/
        popd
    fi
    if sonobuoy run --wait --mode quick 2>/dev/null; then
        sonobuoy results "$(sonobuoy retrieve)"
        rm -f ./*_sonobuoy_*.tar.gz
    else
        sonobuoy status || :
        sonobuoy logs
    fi
    sonobuoy delete --wait --level warn
}

# run_checkov() - Installs and runs checkov tool
function run_checkov {
    kubectl apply -f resources/checkov-job.yaml
    wait_for_pods checkov
    kubectl logs job/checkov -n checkov
    kubectl delete -f resources/checkov-job.yaml
}

# run_kubent() - Installs Kubent to determine deprecated APIs
function run_kubent {
    if ! command -v kubent >/dev/null; then
        curl -sSL https://git.io/install-kubent | GREEN=x TERM=dumb NOCOL=1 YELLOW=x sh
    fi
    kubent
}
