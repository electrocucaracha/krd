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
set -o pipefail
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
fi

function get_github_latest_tag {
    version=""
    attempt_counter=0
    max_attempts=5

    until [ "$version" ]; do
        tags="$(curl -s "https://api.github.com/repos/$1/tags")"
        if [ "$tags" ]; then
            version="$(echo "$tags" | grep -Po '"name":.*?[^\\]",' | awk -F  "\"" 'NR==1{print $4}')"
            break
        elif [ ${attempt_counter} -eq ${max_attempts} ];then
            echo "Max attempts reached"
            exit 1
        fi
        attempt_counter=$((attempt_counter+1))
        sleep 2
    done

    echo "${version#*v}"
}

robox_latest_version="$(get_github_latest_tag lavabit/robox)"
cat << EOT > distros_supported.yml
---
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

clearlinux:
  latest:
    name: AntonioMeireles/ClearLinux
centos:
  7:
    name: generic/centos7
    version: $robox_latest_version
  8:
    name: generic/centos8
    version: $robox_latest_version
ubuntu:
  xenial:
    name: generic/ubuntu1604
    version: $robox_latest_version
  bionic:
    name: generic/ubuntu1804
    version: $robox_latest_version
  focal:
    name: generic/ubuntu2004
    version: $robox_latest_version
opensuse:
  42:
    name: generic/opensuse42
    version: $robox_latest_version
fedora:
  32:
    name: generic/fedora32
    version: $robox_latest_version
  33:
    name: generic/fedora33
    version: $robox_latest_version
EOT
