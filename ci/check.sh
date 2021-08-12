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
pushd ../tests > /dev/null
# shellcheck source=tests/_assertions.sh
source _assertions.sh
popd > /dev/null

VAGRANT_CMD_SSH_INSTALLER="$VAGRANT_CMD ssh installer --"
VAGRANT_CMD_SSH_AIO="$VAGRANT_CMD ssh aio --"

function _exit_trap {
    if [ -f  /proc/stat ]; then
        printf "CPU usage: "
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
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
    if [[ "${KRD_KATA_CONTAINERS_ENABLED:-false}"  == "true" ]]; then
        $VAGRANT_CMD_SSH_AIO "/opt/kata/bin/kata-runtime kata-env"
        $VAGRANT_CMD_SSH_AIO "sudo journalctl --since -5m | grep 'kata-runtime'"
    fi
}

function _provision_installer {
    info "Provisioning Kubernetes cluster"

    if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
        KRD_DEBUG=true ./krd_command.sh -a install_k8s
    else
        $VAGRANT_CMD_UP installer
    fi
}

function _run_assertions {
    info "Running Assertions"

    if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
        assert_contains "$(command -v kubectl)" "kubectl"
        assert_are_equal "${KRD_KUBE_VERSION:-v1.20.7}" "$(kubectl version --short | awk 'FNR==2{print $3}')"
        pushd /opt/kubespray > /dev/null
        assert_are_equal "${KRD_KUBESPRAY_VERSION:-v2.16.0}" "$(git describe --abbrev=0 --tags)"
        popd > /dev/null
    else
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "command -v kubectl")" "kubectl"
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "kubectl version --short | awk 'FNR==2{print \$3}'")" "${KRD_KUBE_VERSION:-v1.20.7}"
        assert_contains "$($VAGRANT_CMD_SSH_INSTALLER "cd /opt/kubespray; git describe --abbrev=0 --tags")" "${KRD_KUBESPRAY_VERSION:-v2.16.0}"
    fi
}

function _run_installer_cmd {
    if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
        pushd "${1}" > /dev/null
        "${@:2}"
        popd > /dev/null
    else
        # shellcheck disable=SC2145
        $VAGRANT_CMD_SSH_INSTALLER "cd /vagrant/${1}; ${@:2}"
    fi
}

function _run_integration_tests {
    local int_test=("${KRD_INT_TESTS:-kong metallb istio haproxy kubevirt falco knative rook gatekeeper}")

    info "Running Integration tests (${int_test[*]})"

    _run_installer_cmd tests KRD_DEBUG=false ./check.sh "${int_test[@]}"
}

function _test_virtlet {
    info "Testing Virtlet services"

    _run_installer_cmd . KRD_DEBUG=false KRD_ENABLE_TESTS=true KRD_DEBUG=true KRD_ADDONS_LIST=virtlet ./krd_command.sh -a install_k8s_addons
}

function _test_runtime_classes {
    info "Testing Kubernetes Runtime Classes"

    _run_installer_cmd tests KRD_DEBUG=false ./runtimeclasses.sh
}

if [[ "${HOST_INSTALLER:-false}" == "true" ]]; then
    info "Configure SSH keys"

    sudo mkdir -p /root/.ssh/
    sudo cp insecure_keys/key /root/.ssh/id_rsa
    cp insecure_keys/key ~/.ssh/id_rsa
    sudo chmod 400 /root/.ssh/id_rsa
    chown "$USER" ~/.ssh/id_rsa
    chmod 400 ~/.ssh/id_rsa
fi

trap _exit_trap ERR
_provision_installer
_run_assertions
if [[ "${KRD_ENABLE_TESTS:-false}" == "true" ]]; then
    _run_integration_tests
fi
if [[ "${TEST_VIRTLET:-false}" == "true" ]]; then
    _test_virtlet
fi
if [[ "${TEST_RUNTIMECLASSES:-false}" == "true" ]]; then
    _test_runtime_classes
fi
