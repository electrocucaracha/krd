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

if [ "${KRD_DEBUG:-false}" == "true" ]; then
    set -o xtrace
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

    sfdisk "$dev_name" --no-reread << EOF
;
EOF
    mkfs -t ext4 "${dev_name}1"
    mkdir -p "$mount_dir"
    mount "${dev_name}1" "$mount_dir"
    echo "${dev_name}1 $mount_dir           ext4    errors=remount-ro,noatime,barrier=0 0       1" >> /etc/fstab
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

swapoff -a
if [[ -n "${dict_volumes+x}" ]]; then
    for kv in ${dict_volumes//,/ } ;do
        mount_external_partition "${kv%=*}" "${kv#*=}"
    done
fi

vendor_id=$(lscpu|grep "Vendor ID")
if [[ $vendor_id == *GenuineIntel* ]]; then
    kvm_ok=$(cat /sys/module/kvm_intel/parameters/nested)
    if [[ $kvm_ok == 'N' ]]; then
        echo "Enable Intel Nested-Virtualization"
        rmmod kvm-intel
        echo 'options kvm-intel nested=y' >> /etc/modprobe.d/dist.conf
        modprobe kvm-intel
        echo kvm-intel >> /etc/modules
    fi
else
    kvm_ok=$(cat /sys/module/kvm_amd/parameters/nested)
    if [[ $kvm_ok == '0' ]]; then
        echo "Enable AMD Nested-Virtualization"
        rmmod kvm-amd
        sh -c "echo 'options kvm-amd nested=1' >> /etc/modprobe.d/dist.conf"
        modprobe kvm-amd
        echo kvm-amd >> /etc/modules
    fi
fi
modprobe vhost_net
echo vhost_net >> /etc/modules
common_pkgs=(hwloc ndctl)
# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
        INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends ${common_pkgs[*]}"
    ;;
    ubuntu|debian)
        INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install ${common_pkgs[*]} cpu-checker"
        kvm-ok
    ;;
    rhel|centos|fedora)
        PKG_MANAGER=$(command -v dnf || command -v yum)
        INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install ${common_pkgs[*]}"
#        if ! sudo yum repolist | grep "epel/"; then
#            $INSTALLER_CMD epel-release
#        fi
#        sudo "$PKG_MANAGER" updateinfo
    ;;
esac

${INSTALLER_CMD}
if command -v kvm-ok; then
    kvm-ok
fi
#if lsblk -t | grep pmem; then
#    for namespace in $(ndctl list | jq -r '((. | arrays | .[]), . | objects) | select(.mode == "raw") | .dev'); do
#        sudo ndctl create-namespace -f -e "$namespace" --mode=memory
#    done
#fi
