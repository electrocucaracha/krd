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

# Configuration values
KRD_FOLDER="$(pwd)"
export KRD_FOLDER

# shellcheck source=_commons.sh
source _commons.sh
# shellcheck source=_installers.sh
source _installers.sh

if ! sudo -n "true"; then
    echo ""
    echo "passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

if [[ "${KRD_DEBUG}" == "true" ]]; then
    set -o xtrace
    verbose="-vvv"
fi

update_repos
for installer in ${KRD_INSTALLERS:-k8s addons helm_charts rundeck}; do
    "install_$installer"
done
