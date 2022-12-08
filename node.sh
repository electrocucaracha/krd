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
set -o nounset

source defaults.env

if [[ $KRD_DEBUG == "true" ]]; then
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

    sudo sfdisk "$dev_name" --no-reread <<EOF
;
EOF
    sudo mkfs -t ext4 "${dev_name}1"
    sudo mkdir -p "$mount_dir"
    sudo mount "${dev_name}1" "$mount_dir"
    # NOTE: barrier=0 - Write barriers are used to enforce proper on-disk
    # ordering of journal commits, but they will degrade the performance of the
    # file system. However, if the system does not have battery-backed disks,
    # there is a risk of file system corruption. Since etcd uses write-ahead
    # logging and calls fsync every time it commits to the raft log, it’s okay
    # to disable the write barrier.
    # commit=60 - The number of seconds for each data and meta data sync.
    echo "${dev_name}1 $mount_dir           ext4    errors=remount-ro,noatime,barrier=0,commit=60 0       1" | sudo tee --append /etc/fstab
}

# disable_swap() - Disable Swap
function disable_swap {
    # Fedora 33 introduces zram-generator service - https://fedoraproject.org/wiki/Changes/SwapOnZRAM
    if systemctl is-active --quiet swap-create@zram0; then
        sudo systemctl stop swap-create@zram0
        sudo touch /etc/systemd/zram-generator.conf
    fi
    if [ -n "$(sudo swapon --show)" ]; then
        if [ "$KRD_DEBUG" == "true" ]; then
            sudo swapon --show
            sudo blkid
        fi
        for dev in $(sudo swapon --show=NAME --noheadings); do
            sudo swapoff "$dev"
        done
        sudo sed -i -e '/swap/d' /etc/fstab
    fi
}

# enable_hugepages() - Enable Hugepages
function enable_hugepages {
    echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
    sudo mkdir -p /mnt/huge
    sudo mount -t hugetlbfs nodev /mnt/huge
    echo 1024 | sudo tee /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages
}

# ensure_kmod() - Ensures that a specific Kernel module is loaded
function ensure_kmod {
    sudo modprobe "$1"
    sudo mkdir -p /etc/modules-load.d/
    echo "$1" | sudo tee "/etc/modules-load.d/krd-$1.conf"
}

# install_deps() - Install minimal dependencies required
function install_deps {
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
    ubuntu | debian)
        if ! command -v curl >/dev/null; then
            sudo apt-get update
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 curl
        fi
        if ! command -v deborphan >/dev/null; then
            sudo apt-get update
            sudo apt-get install -y -qq -o=Dpkg::Use-Pty=0 deborphan
        fi
        sudo du -sh /var/cache/apt/archives
        sudo apt-get clean
        ;;
    rhel | centos | fedora)
        if command -v yum >/dev/null; then
            yum clean all --verbose
            sudo rm -rf /var/cache/yum
            if command -v package-cleanup >/dev/null; then
                for arg in leaves leaves orphans; do
                    package-cleanup --quiet "--$arg"
                    package-cleanup --quiet "--$arg" | xargs sudo yum remove -y || :
                done
            fi
        fi
        if command -v dnf >/dev/null; then
            sudo dnf clean all
            eval "sudo dnf remove $(sudo dnf repoquery --installonly --latest-limit=-2 -q)"
            sudo dnf clean packages
        fi
        if [ "${VERSION_ID}" == "7" ]; then
            PKG_PYTHON_MAJOR_VERSION=2
            export PKG_PYTHON_MAJOR_VERSION
        fi
        if ! command -v iptables >/dev/null; then
            sudo -H -E "$(command -v dnf || command -v yum)" -q -y install iptables-legacy
        fi
        ;;
    *suse)
        PKG_PYTHON_MAJOR_VERSION=2
        export PKG_PYTHON_MAJOR_VERSION
        ;;
    esac

    if ! command -v bindep >/dev/null; then
        curl -fsSL http://bit.ly/install_bin | PKG_BINDEP_PROFILE=node bash
    else
        pkgs="$(bindep node -b || :)"
        if [ "$pkgs" ]; then
            curl -fsSL http://bit.ly/install_pkg | PKG=$pkgs bash
        fi
    fi
    if systemctl list-unit-files tuned.service | grep "1 unit"; then
        sudo sed -i "s|#\!/usr/bin/python |#\!$(command -v python2) |g" /usr/sbin/tuned
        sudo systemctl start tuned
        sudo systemctl enable tuned
        # This profile favors performance over power savings by setting
        # intel_pstate and min_perf_pct=100. It disables transparent huge pages,
        # and automatic NUMA balancing. It also uses cpupower to set the
        # performance cpufreq governor, and requests a cpu_dma_latency value of
        # 1. It also sets busy_read and busy_poll times to 50 μs, and
        # tcp_fastopen to 3.
        sudo tuned-adm profile network-latency
    fi

    # Free up space
    if command -v deborphan >/dev/null; then
        eval "sudo apt-get remove --purge -y $(deborphan)" || :
    fi
    sudo journalctl --disk-usage
    sudo journalctl --vacuum-time=1m
}

# mount_partitions() - Mount and format additional volumes
function mount_partitions {
    if [ -n "${dict_volumes-}" ]; then
        for kv in ${dict_volumes//,/ }; do
            mount_external_partition "${kv%=*}" "${kv#*=}"
        done
    fi
}

# disable_k8s_ports() - Disable FirewallD ports used by Kubernetes Kubelet
function disable_k8s_ports {
    local kubelet_ports=(6443 10250 10259 10257)

    for port in "${kubelet_ports[@]}"; do
        if command -v netstat >/dev/null && netstat -atun | grep -q "$port"; then
            echo "Port $port is already used by other non-kubelet service"
            exit 1
        fi
    done

    if command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
        for port in "${kubelet_ports[@]}"; do
            sudo firewall-cmd --zone=public --permanent --add-port="$port/tcp"
        done
        sudo firewall-cmd --zone=public --permanent --add-service=https
        sudo firewall-cmd --reload
        if [ "$KRD_DEBUG" == "true" ]; then
            sudo firewall-cmd --get-active-zones
            sudo firewall-cmd --zone=public --list-services
            sudo firewall-cmd --zone=public --list-ports
        fi
    fi
}

# create_pmem_namespaces() - Creates Persistent Memory namespaces
function create_pmem_namespaces {
    if lsblk -t | grep pmem && command -v ndctl >/dev/null && command -v jq >/dev/null; then
        for namespace in $(ndctl list | jq -r '((. | arrays | .[]), . | objects) | select(.mode == "raw") | .dev'); do
            sudo ndctl create-namespace -f -e "$namespace" --mode=memory || true
        done
        if [ "$KRD_DEBUG" == "true" ]; then
            sudo ndctl list -iNRD
        fi
    fi
}

# enable_nvdimm_mixed_mode() - Enable NVDIMM mixed mode (configuration for MM:AD is set to 50:50)
function enable_nvdimm_mixed_mode {
    if command -v ipmctl >/dev/null && [[ "$(sudo ipmctl show -dimm | awk -F'|' 'FNR==3{print $4}')" == *"Healthy"* ]]; then
        sudo ipmctl create -goal memorymode=50 persistentmemorytype=appdirect
        sudo ipmctl create -goal memorymode=50 persistentmemorytype=appdirectnotinterleaved
    fi
}

# change_ip_precedence() - Prefer IPv4 over IPv6 in dual-stack environment
function change_ip_precedence {
    if [ -f /etc/gai.conf ]; then
        sudo sed -i "s|^#precedence ::ffff:0:0/96  100$|precedence ::ffff:0:0/96  100|g" /etc/gai.conf
    fi
}

# set_dns_server - Change default DNS server configuration
function set_dns_server {
    if command -v systemd-resolve >/dev/null && sudo systemd-resolve --status --interface eth0; then
        sudo systemd-resolve --interface eth0 --set-dns 1.1.1.1 --flush-caches
        sudo systemd-resolve --status --interface eth0
    fi
    if [ -f /etc/netplan/01-netcfg.yaml ]; then
        sudo sed -i "s/addresses: .*/addresses: [1.1.1.1, 8.8.8.8, 8.8.4.4]/g" /etc/netplan/01-netcfg.yaml
        sudo netplan apply
    fi
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf
    fi
}

while getopts "h?v:" opt; do
    case $opt in
    v)
        dict_volumes="$OPTARG"
        ;;
    h | \?)
        usage
        exit
        ;;
    esac
done

change_ip_precedence
set_dns_server
disable_swap
# Some containers doesn't support Hugepages (https://github.com/docker-library/postgres/issues/451#issuecomment-447472044)
if [ "$KRD_HUGEPAGES_ENABLED" == "true" ]; then
    enable_hugepages
fi
# rbd - Rook Ceph requires a Linux kernel built with the RBD module
# ip6table_filter - Ensure Filter IP6 table exists
for kmod in rbd ip6table_filter; do
    ensure_kmod "$kmod"
done
install_deps
mount_partitions
disable_k8s_ports
create_pmem_namespaces
enable_nvdimm_mixed_mode

if [ "$KRD_DEBUG" == "true" ]; then
    if command -v lstopo-no-graphics >/dev/null; then
        lstopo-no-graphics
    fi
    if command -v ipvsadm >/dev/null; then
        sudo ipvsadm -Ln
    fi
fi
