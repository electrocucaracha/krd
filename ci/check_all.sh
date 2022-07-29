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

output=""
for os in fedora ubuntu centos opensuse; do
    for release in $(shyaml keys "$os" < ../distros_supported.yml); do
        for cni in flannel cilium calico; do
            for cri in containerd crio; do
                output+="{\"os\": \"$os\", \"release\": \"$release\", \"plugin\": \"$cni\", \"runtime\": \"$cri\"},"
            done
        done
    done
done

length=${#output}
echo "::set-output name=matrix::[${output::length-1}]"
