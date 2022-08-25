#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=tests/_utils.sh
source ../tests/_utils.sh

# run_installer_cmd() - Runs a specific command on the installer node
function run_installer_cmd {
    if [[ ${HOST_INSTALLER:-false} == "true" ]]; then
        pushd "${1}" >/dev/null
        KRD_DEBUG=false "${@:2}"
        popd >/dev/null
    else
        # shellcheck disable=SC2145
        $VAGRANT_CMD_SSH_INSTALLER "cd /vagrant/${1}; KRD_DEBUG=false ${@:2}"
    fi
}

if ! command -v vagrant >/dev/null; then
    # NOTE: Shorten link -> https://github.com/electrocucaracha/bootstrap-vagrant
    curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash
fi

VAGRANT_CMD=""
if [[ ${SUDO_VAGRANT_CMD:-false} == "true" ]]; then
    VAGRANT_CMD="sudo -H"
fi
VAGRANT_CMD+=" $(command -v vagrant)"
# shellcheck disable=SC2034
VAGRANT_CMD_UP="$VAGRANT_CMD up --no-destroy-on-error"
VAGRANT_CMD_SSH_INSTALLER="$VAGRANT_CMD ssh installer --"
