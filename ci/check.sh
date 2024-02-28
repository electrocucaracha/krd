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

# shellcheck source=ci/_common.sh
source _common.sh
pushd ../tests >/dev/null
# shellcheck source=tests/_assertions.sh
source _assertions.sh
popd >/dev/null

function _exit_trap {
    VAGRANT_CMD_SSH_AIO="$VAGRANT_CMD ssh aio --"

    if [ -f /proc/stat ]; then
        printf "CPU usage: "
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    fi
    if [ -f /proc/pressure/io ]; then
        printf "I/O Pressure Stall Information (PSI): "
        grep full /proc/pressure/io | awk '{ sub(/avg300=/, ""); print $4 }'
    fi
    printf "Memory free(Kb):"
    if [ -f /proc/zoneinfo ]; then
        awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    fi
    if command -v vm_stat; then
        vm_stat | awk '/Pages free/ {print $3 * 4 }'
    fi
    echo "Environment variables:"
    env | grep "KRD"
    echo "Kubelet Errors:"
    $VAGRANT_CMD_SSH_AIO "sudo journalctl -u kubelet --since -5m | grep -E 'E[0-9]+|error|Error'"
    echo "${KRD_CONTAINER_RUNTIME:-docker} Errors:"
    $VAGRANT_CMD_SSH_AIO "sudo journalctl -u ${KRD_CONTAINER_RUNTIME:-docker} --since -5m | grep -E 'E[0-9]+|error|Error'"
    if [[ ${KRD_KATA_CONTAINERS_ENABLED:-false} == "true" ]]; then
        $VAGRANT_CMD_SSH_AIO "/opt/kata/bin/kata-runtime kata-env"
        $VAGRANT_CMD_SSH_AIO "sudo journalctl --since -5m | grep 'kata-runtime'"
    fi
}

function _run_assertions {
    info "Running Assertions"

    if [[ ${HOST_INSTALLER:-false} == "true" ]]; then
        assert_contains "$(command -v kubectl)" "kubectl"
        assert_are_equal "${KRD_KUBE_VERSION:-v1.28.6}" "$(kubectl version -o yaml | grep gitVersion | awk 'FNR==2{ print $2}')"
        pushd /opt/kubespray >/dev/null
        assert_are_equal "${KRD_KUBESPRAY_VERSION:-v2.24.1}" "$(git describe --abbrev=0 --tags)"
        popd >/dev/null
    else
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "command -v kubectl")" "kubectl"
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "kubectl version -o yaml | grep gitVersion | awk 'FNR==2{ print \$2}'")" "${KRD_KUBE_VERSION:-v1.28.6}"
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "cd /opt/kubespray; git describe --abbrev=0 --tags")" "${KRD_KUBESPRAY_VERSION:-v2.24.1}"
    fi
}

function _run_integration_tests {
    local int_test=("${KRD_INT_TESTS:-kong metallb istio haproxy kubevirt virtink falco knative rook kyverno gatekeeper}")

    info "Running Integration tests (${int_test[*]})"

    run_installer_cmd tests ./check.sh "${int_test[@]}"
}

function _run_conformance_tools {
    for tool in sonobuoy kubescape checkov; do
        info "Running $tool tool"
        run_installer_cmd . ./krd_command.sh -a "run_$tool"
    done
}

function _run_benchmarks {
    info "Running K6 tool internally"
    run_installer_cmd . ./krd_command.sh -a run_internal_k6

    info "Running iperf tool"
    run_installer_cmd . ./krd_command.sh -a run_k8s_iperf
}

function _test_virtlet {
    info "Testing Virtlet services"
    run_installer_cmd . KRD_ENABLE_TESTS=true KRD_ADDONS_LIST=virtlet ./krd_command.sh -a install_k8s_addons
}

function _test_runtime_classes {
    info "Testing Kubernetes Runtime Classes"
    run_installer_cmd tests ./runtimeclasses.sh
}

if [[ ${HOST_INSTALLER:-false} == "true" ]]; then
    info "Configure SSH keys"

    sudo mkdir -p /root/.ssh/
    sudo cp insecure_keys/key /root/.ssh/id_rsa
    cp insecure_keys/key ~/.ssh/id_rsa
    sudo chmod 400 /root/.ssh/id_rsa
    chown "$USER" ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
fi

trap _exit_trap ERR
_run_assertions
if [[ ${KRD_ENABLE_TESTS:-false} == "true" ]]; then
    _run_integration_tests
fi
if [[ ${TEST_VIRTLET:-false} == "true" ]]; then
    _test_virtlet
fi
if [[ ${KRD_KATA_CONTAINERS_ENABLED:-false} == "true" ]] || [[ ${KRD_CRUN_ENABLED:-false} == "true" ]] || [[ ${KRD_GVISOR_ENABLED:-false} == "true" ]]; then
    _test_runtime_classes
fi
if [[ ${RUN_CONFORMANCE_TOOLS:-false} == "true" ]]; then
    _run_conformance_tools
fi
if [[ ${RUN_BENCHMARKS:-false} == "true" ]]; then
    _run_benchmarks
fi
