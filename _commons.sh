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
    echo "Updating repositories list..."
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
            UPDATE_CMD='zypper -n ref'
        ;;
        ubuntu|debian)
            UPDATE_CMD='apt update'
        ;;
        rhel|centos|fedora)
            UPDATE_CMD='yum updateinfo'
        ;;
        clear-linux-os)
            UPDATE_CMD='swupd update'
        ;;
    esac
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        eval "sudo ${UPDATE_CMD}"
    else
        eval "sudo ${UPDATE_CMD} > /dev/null"
    fi
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

# _install_packages() - Install a list of packages
function _install_packages {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            sudo apt-get install -y -qq "$@"
        ;;
        rhel|centos|fedora)
        ;;
    esac
}

# _install_package() - Install specific package if doesn't exist
function _install_package {
    local package=$1

    if ! _is_package_installed "$package"; then
        echo "Installing $package..."

        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            *suse)
                sudo zypper install -y "$package"
            ;;
            ubuntu|debian)
                if [ "${KRD_DEBUG:-false}" == "true" ]; then
                    sudo apt-get install -y "$package"
                else
                    sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 "$package"
                fi
            ;;
            rhel|centos|fedora)
                PKG_MANAGER=$(command -v dnf || command -v yum)
                sudo "$PKG_MANAGER" -y install "$package"
            ;;
            clear-linux-os)
                sudo swupd bundle-add "$package"
            ;;
        esac
    fi
}

# _get_version() - Get the version number declared in configuration file
function _get_version {
    grep "${1}_version:" "$krd_playbooks/krd-vars.yml" | awk -F ': ' '{print $2}'
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

# Configuration values
if ! command -v git; then
    _install_package git
fi
KRD_FOLDER="$(git rev-parse --show-toplevel)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_playbooks=$KRD_FOLDER/playbooks
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray

ansible_cmd="sudo -E ansible-playbook --become "
if [[ "${KRD_DEBUG:-false}" == "true" ]]; then
    set -o xtrace
    ansible_cmd+="-vvv "
fi
ansible_cmd+="-i $krd_inventory "
