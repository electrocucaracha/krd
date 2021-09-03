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

if ! command -v shyaml; then
    pip install shyaml
fi

# PEP 370 -- Per user site-packages directory
[[ "$PATH" != *.local/bin* ]] && export PATH=$PATH:$HOME/.local/bin
[[ "$PATH" != */Library/Frameworks/Python.framework/Versions/2.7/bin* ]] && export PATH=$PATH:/Library/Frameworks/Python.framework/Versions/2.7/bin

for OS in fedora ubuntu centos; do
    for RELEASE in $(shyaml keys "$OS" < ../distros_supported.yml); do
        info "Provisioning $OS $RELEASE target node..."
        ./bootstrap.sh
        ./provision_installer.sh
        ./check.sh
    done
done
