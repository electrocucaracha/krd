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

if ! command -v vagrant > /dev/null; then
    # NOTE: Shorten link -> https://github.com/electrocucaracha/bootstrap-vagrant
    curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash
fi

VAGRANT_CMD=""
if [[ "${SUDO_VAGRANT_CMD:-false}" == "true" ]]; then
    VAGRANT_CMD="sudo -H"
fi
VAGRANT_CMD+=" $(command -v vagrant)"
# shellcheck disable=SC2034
VAGRANT_CMD_UP="$VAGRANT_CMD up --no-destroy-on-error"
