#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
set -o errexit
if [ "${KRD_DEBUG:-false}" == "true" ]; then
    set -o xtrace
    export PKG_DEBUG=true
fi

# usage() - Prints the usage of the program
function usage {
    cat <<EOF
usage: $0 [-v volumes]
Optional Argument:
    -v List of key pair values for volumes and mount points ( e. g. sda=/var/lib/docker/,sdb=/var/lib/libvirt/ )
EOF
}

# mount_external_partition() - Create partition and mount the external volume
function mount_external_partition {
    local dev_name="/dev/$1"
    local mount_dir=$2

    sudo sfdisk "$dev_name" --no-reread << EOF
;
EOF
    sudo mkfs -t ext4 "${dev_name}1"
    sudo mkdir -p "$mount_dir"
    sudo mount "${dev_name}1" "$mount_dir"
    echo "${dev_name}1 $mount_dir           ext4    errors=remount-ro,noatime,barrier=0 0       1" | sudo tee --append /etc/fstab
}

# disable_swap() - Disable Swap
function disable_swap {
    sudo swapoff -a
    sudo sed -i -e '/swap/d' /etc/fstab
}

# enable_huge_pages() - Enable Huge pages
function enable_huge_pages {
    echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
    sudo mkdir -p /mnt/huge
    sudo mount -t hugetlbfs nodev /mnt/huge
    echo 1024 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
}

# enable_rbd() - Rook Ceph requires a Linux kernel built with the RBD module
function enable_rbd {
    sudo modprobe rbd
}

# _install_deps() - Install minimal dependencies required
function _install_deps {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    if ! command -v curl; then
        case ${ID,,} in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
            ;;
        esac
    fi
    case ${ID,,} in
        rhel|centos|fedora)
            if [ "${VERSION_ID}" == "7" ]; then
                PKG_PYTHON_MAJOR_VERSION=2
                export PKG_PYTHON_MAJOR_VERSION
            fi
        ;;
        *suse)
            PKG_PYTHON_MAJOR_VERSION=2
            export PKG_PYTHON_MAJOR_VERSION
        ;;
    esac

    PATH="$PATH:/usr/local/bin/"
    export PATH
    curl -fsSL http://bit.ly/install_pkg | PKG=bindep bash
    curl -fsSL http://bit.ly/install_pkg | PKG="$(bindep node -b)" bash
    if systemctl list-unit-files tuned.service | grep "1 unit"; then
        sudo sed -i "s|#\!/usr/bin/python |#\!$(command -v python2) |g" /usr/sbin/tuned
        sudo systemctl start tuned
        sudo systemctl enable tuned
    fi
}

while getopts "h?v:" opt; do
    case $opt in
        v)
            dict_volumes="$OPTARG"
            ;;
        h|\?)
            usage
            exit
            ;;
    esac
done

disable_swap
enable_huge_pages
enable_rbd
_install_deps

echo "Sync server's clock"
sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"

if [ -n "${dict_volumes:-}" ]; then
    for kv in ${dict_volumes//,/ } ;do
        mount_external_partition "${kv%=*}" "${kv#*=}"
    done
fi
if command -v firewall-cmd && systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp
    sudo firewall-cmd --zone=public --permanent --add-service=https
    sudo firewall-cmd --reload
    if [ "${KRD_DEBUG:-false}" == "true" ]; then
        sudo firewall-cmd --get-active-zones
        sudo firewall-cmd --zone=public --list-services
        sudo firewall-cmd --zone=public --list-ports
    fi
fi

## TODO: Improve PMEM setup

#if lsblk -t | grep pmem; then
#    # shellcheck disable=SC1091
#    source /etc/os-release || source /usr/lib/os-release
#    case ${ID,,} in
#        rhel|centos|fedora)
#            for repo in ipmctl safeclib; do
#                curl -o "/etc/yum.repos.d/${repo}-epel-7.repo" "https://copr.fedorainfracloud.org/coprs/jhli/${repo}/repo/epel-7/jhli-${repo}-epel-7.repo"
#            done
#            INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install ipmctl ndctl"
#        ;;
#    esac
#    ${INSTALLER_CMD}
#    if command -v ndctl && command -v jq; then
#        for namespace in $(ndctl list | jq -r '((. | arrays | .[]), . | objects) | select(.mode == "raw") | .dev'); do
#            sudo ndctl create-namespace -f -e "$namespace" --mode=memory
#        done
#    fi
#fi

# Enable NVDIMM mixed mode (configuration for MM:AD is set to 50:50)
#if command -v ipmctl; then
#    ipmctl create -goal memorymode=50 persistentmemorytype=appdirect 2>&1 /dev/null
#    ipmctl create -goal memorymode=50 persistentmemorytype=appdirectnotinterleaved 2>&1 /dev/null
#fi
