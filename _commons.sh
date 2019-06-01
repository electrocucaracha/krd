#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
#############################################################################

# Configuration values
KRD_FOLDER="$(pwd)"
export KRD_FOLDER

export krd_inventory_folder=$KRD_FOLDER/inventory
export krd_inventory=$krd_inventory_folder/hosts.ini
export kubespray_folder=/opt/kubespray

verbose=""
if [[ "${KRD_DEBUG}" == "true" ]]; then
    set -o xtrace
    verbose="-vvv"
fi
export verbose

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
    if [[ "$KRD_DEBUG" == "true" ]]; then
        eval "sudo ${UPDATE_CMD}"
    else
        eval "sudo ${UPDATE_CMD} > /dev/null"
    fi
}

# is_package_installed() - Function to tell if a package is installed
function is_package_installed {
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

# install_packages() - Install a list of packages
function install_packages {
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

# install_package() - Install specific package if doesn't exist
function install_package {
    local package=$1

    if ! is_package_installed "$package"; then
        echo "Installing $package..."

        # shellcheck disable=SC1091
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            *suse)
                sudo zypper install -y "$package"
            ;;
            ubuntu|debian)
                if [[ "$KRD_DEBUG" == "true" ]]; then
                    sudo apt-get install -y "$package"
                else
                    sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 "$package"
                fi
            ;;
            rhel|centos|fedora)
                PKG_MANAGER=$(command -v dnf || command -v yum)
                sudo "$PKG_MANAGER" -y install "$package"
            ;;
        esac
    fi
}

# uninstall_packages() - Uninstall a list of packages
function uninstall_packages {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            sudo apt-get purge -y -qq "$@"
        ;;
        rhel|centos|fedora)
        ;;
    esac
}

# uninstall_package() - Uninstall specific package if exists
function uninstall_package {
    local package=$1

    # shellcheck disable=SC1091
    if is_package_installed "$package"; then
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            *suse)
            ;;
            ubuntu|debian)
                sudo apt-get purge -y -qq "$package"
            ;;
            rhel|centos|fedora)
            ;;
        esac
    fi
}
