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
    if [ -f $krd_folder/sources.list ]; then
        sudo mv /etc/apt/sources.list /etc/apt/sources.list.backup
        sudo cp $krd_folder/sources.list /etc/apt/sources.list
    fi
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
            UPDATE_CMD='zypper -n ref'
        ;;
        ubuntu|debian)
            UPDATE_CMD='apt-get update'
        ;;
        rhel|centos|fedora)
            UPDATE_CMD='yum updateinfo'
        ;;
    esac
    if [[ "$KRD_DEBUG" == "true" ]]; then
        sudo ${UPDATE_CMD}
    else
        sudo ${UPDATE_CMD} > /dev/null
    fi
}

# is_package_installed() - Function to tell if a package is installed
function is_package_installed {
    if [[ -z "$@" ]]; then
        return 1
    fi
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
    sudo ${CHECK_CMD} "$@" &> /dev/null
}

# install_packages() - Install a list of packages
function install_packages {
    local packages=$@
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            sudo apt-get install -y -qq $packages
        ;;
        rhel|centos|fedora)
        ;;
    esac
}

# install_package() - Install specific package if doesn't exist
function install_package {
    local package=$1

    if ! is_package_installed $package; then
        echo "Installing $package..."

        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            *suse)
                sudo zypper install -y $package
            ;;
            ubuntu|debian)
                if [[ "$KRD_DEBUG" == "true" ]]; then
                    sudo apt-get install -y $package
                else
                    sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 $package
                fi
            ;;
            rhel|centos|fedora)
                PKG_MANAGER=$(which dnf || which yum)
                sudo ${PKG_MANAGER} -y install $package
            ;;
        esac
    fi
}

# uninstall_packages() - Uninstall a list of packages
function uninstall_packages {
    local packages=$@
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        *suse)
        ;;
        ubuntu|debian)
            sudo apt-get purge -y -qq $packages
        ;;
        rhel|centos|fedora)
        ;;
    esac
}

# uninstall_package() - Uninstall specific package if exists
function uninstall_package {
    local package=$1
    if is_package_installed $package; then
        source /etc/os-release || source /usr/lib/os-release
        case ${ID,,} in
            *suse)
            ;;
            ubuntu|debian)
                sudo apt-get purge -y -qq $package
            ;;
            rhel|centos|fedora)
            ;;
        esac
    fi
}
