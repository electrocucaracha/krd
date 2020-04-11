#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
#############################################################################

# update_repos() - Function that updates linux repositories
function update_repos {
    curl -fsSL http://bit.ly/install_pkg | PKG_UPDATE="true" bash
}

# _is_package_installed() - Function to tell if a package is installed
function _is_package_installed {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
            CHECK_CMD="zypper search --match-exact --installed"
        ;;
        ubuntu|debian)
            CHECK_CMD="dpkg -l"
        ;;
        rhel|centos|fedora)
            CHECK_CMD="rpm -q"
        ;;
    esac
    sudo "${CHECK_CMD}" "$@" &> /dev/null
}

# _install_package() - Install specific package if doesn't exist
function _install_packages {
    sanity_pkgs=""
    for pkg in "$@"; do
        if ! _is_package_installed "$pkg"; then
            sanity_pkgs+="$pkg"
        fi
    done
    curl -fsSL http://bit.ly/install_pkg | PKG="$sanity_pkgs" bash
}

# _get_version() - Get the version number declared in configuration file
function _get_version {
    grep "^${1}_version:" "$krd_playbooks/krd-vars.yml" | awk -F ': ' '{print $2}'
}

# _vercmp() - Function that compares two versions
function _vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
        "==")
            [ "$v1" = "$v2" ]
            return
            ;;
        ">")
            [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
            return
            ;;
        "<")
            [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
            return
            ;;
        ">=")
            [ "$result" = "$v2" ]
            return
            ;;
        "<=")
            [ "$result" = "$v1" ]
            return
            ;;
        *)
            die $LINENO "unrecognised op: $op"
            ;;
    esac
}

function _run_ansible_cmd {
    local playbook=$1
    local log=$2

    ansible_cmd="ANSIBLE_ROLES_PATH=/tmp/galaxy-roles sudo -E $(command -v ansible-playbook) --become "
    if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
        set -o xtrace
        ansible_cmd+="-vvv "
    fi
    ansible_cmd+="-i $krd_inventory "
    echo "$ansible_cmd $playbook"
    eval "$ansible_cmd $playbook" | tee "$log"
}

# Requirements
if ! command -v curl; then
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
        ;;
    esac
fi
if ! command -v git; then
    _install_packages git
fi

# Configuration values
KRD_FOLDER="$(git rev-parse --show-toplevel)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_playbooks=$KRD_FOLDER/playbooks
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
    export PKG_DEBUG=true
fi
