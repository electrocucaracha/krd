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

# shellcheck source=ci/_common.sh
source _common.sh

if [ "$($VAGRANT_CMD status installer | grep "^installer" | awk '{ print $2}')" != "running" ]; then
    provision_installer
else
    run_installer_cmd . ./krd_command.sh -a install_k8s
fi
