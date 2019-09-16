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

vagrant_version=2.2.5
msg="Summary \n"
if ! vagrant version &>/dev/null; then
    enable_vagrant_install=true
else
    if [[ "$vagrant_version" != "$(vagrant version | awk 'NR==1{print $3}')" ]]; then
        enable_vagrant_install=true
    fi
fi

function usage {
    cat <<EOF
usage: $0 -p <PROVIDER> [options]
Installation of vagrant and its dependencies in Linux OS

Argument:
    -p  Vagrant provider
EOF
}

function _reload_grub {
    if command -v grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        sudo update-grub
    elif command -v grub2-mkconfig; then
        grub_cfg="$(sudo readlink -f /etc/grub2.cfg)"
        if dmesg | grep EFI; then
            grub_cfg="/boot/efi/EFI/centos/grub.cfg"
        fi
        sudo grub2-mkconfig -o "$grub_cfg"
    fi
}

function enable_iommu {
    iommu_support=$(sudo virt-host-validate | grep 'Checking for device assignment IOMMU support')
    if [[ "$iommu_support" != *PASS* ]]; then
        echo "WARN - IOMMU support checker reported: $(awk -F':' '{print $3}' <<< "$iommu_support")"
    fi
    iommu_validation=$(sudo virt-host-validate | grep 'Checking if IOMMU is enabled by kernel')
    if [[ "$iommu_validation" == *PASS* ]]; then
        return
    fi
    if [ -f /etc/default/grub ]  && [[ "$(grep GRUB_CMDLINE_LINUX /etc/default/grub)" != *intel_iommu=on* ]]; then
        sudo sed -i "s|^GRUB_CMDLINE_LINUX\(.*\)\"|GRUB_CMDLINE_LINUX\1 intel_iommu=on\"|g" /etc/default/grub
    fi
    _reload_grub
    msg+="- WARN: IOMMU was enabled and requires to reboot the server to take effect\n"
}

function disable_ipv6 {
    if [ ! -f /proc/net/if_inet6 ]; then
        return
    fi
    if [ -f /etc/default/grub ]  && [[ "$(grep GRUB_CMDLINE_LINUX /etc/default/grub)" != *ipv6.disable=1* ]]; then
        sudo sed -i "s|^GRUB_CMDLINE_LINUX\(.*\)\"|GRUB_CMDLINE_LINUX\1 ipv6.disable=1\"|g" /etc/default/grub
    fi
    _reload_grub
    msg+="- WARN: IPv6 was disabled and requires to reboot the server to take effect\n"
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

while getopts ":p:" OPTION; do
    case $OPTION in
    p)
        provider=$OPTARG
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done
if [[ -z "${provider+x}" ]]; then
    usage
    exit 1
fi

case $provider in
    "virtualbox" | "libvirt" )
        export VAGRANT_DEFAULT_PROVIDER=${provider}
        ;;
    * )
        usage
        exit 1
esac
echo "WARN - System files are going to be modified to enable"
echo "Input-output memory management unit technology and to disable"
echo "IPv6. The server may need to be restarted manually."
sleep 10

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release

libvirt_group="libvirt"
packages=()
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"
    packages+=(python-devel)

    # Vagrant installation
    if [[ "${enable_vagrant_install+x}" = "x"  ]]; then
        vagrant_pgp="pgp_keys.asc"
        wget -q https://keybase.io/hashicorp/$vagrant_pgp
        wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.rpm
        gpg --quiet --with-fingerprint $vagrant_pgp
        sudo rpm --import $vagrant_pgp
        sudo rpm --checksig vagrant_${vagrant_version}_x86_64.rpm
        sudo rpm --install vagrant_${vagrant_version}_x86_64.rpm
        rm vagrant_${vagrant_version}_x86_64.rpm
        rm $vagrant_pgp
    fi

    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
        wget -q "http://download.virtualbox.org/virtualbox/rpm/opensuse/$VERSION/virtualbox.repo" -P /etc/zypp/repos.d/
        $INSTALLER_CMD --enablerepo=epel dkms
        wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | rpm --import -
        packages+=(VirtualBox-5.1)
        ;;
        libvirt)
        # vagrant-libvirt dependencies
        packages+=(qemu libvirt libvirt-devel ruby-devel gcc qemu-kvm zlib-devel libxml2-devel libxslt-devel make)
        # NFS
        packages+=(nfs-kernel-server)
        ;;
    esac
    sudo zypper -n ref
    ;;

    ubuntu|debian)
    libvirt_group="libvirtd"
    INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install"
    packages+=(python-dev)

    # Vagrant installation
    if [[ "${enable_vagrant_install+x}" = "x" ]]; then
        wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.deb
        sudo dpkg -i vagrant_${vagrant_version}_x86_64.deb
        rm vagrant_${vagrant_version}_x86_64.deb
    fi

    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
        echo "deb http://download.virtualbox.org/virtualbox/debian trusty contrib" >> /etc/apt/sources.list
        wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
        wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
        packages+=(virtualbox-5.1 dkms)
        ;;
        libvirt)
        # vagrant-libvirt dependencies
        packages+=(qemu libvirt-bin ebtables dnsmasq libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev cpu-checker)
        # NFS
        packages+=(nfs-kernel-server)
        ;;
    esac
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    if ! sudo yum repolist | grep "epel/"; then
        $INSTALLER_CMD epel-release
    fi
    sudo "$PKG_MANAGER" updateinfo
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
    packages+=(python-devel)

    if ! command -v wget; then
        $INSTALLER_CMD wget
    fi
    disable_ipv6

    # Vagrant installation
    if [[ "${enable_vagrant_install+x}" = "x"  ]]; then
        wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.rpm
        $INSTALLER_CMD vagrant_${vagrant_version}_x86_64.rpm
        rm vagrant_${vagrant_version}_x86_64.rpm
    fi

    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
        wget -q http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo -P /etc/yum.repos.d
        $INSTALLER_CMD --enablerepo=epel dkms
        wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | rpm --import -
        packages+=(VirtualBox-5.1)
        ;;
        libvirt)
        # vagrant-libvirt dependencies
        packages+=(qemu libvirt libvirt-devel ruby-devel gcc qemu-kvm)
        # NFS
        packages+=(nfs-utils nfs-utils-lib)
        ;;
    esac
    ;;

esac

# Enable Nested-Virtualization
vendor_id=$(lscpu|grep "Vendor ID")
if [[ $vendor_id == *GenuineIntel* ]]; then
    kvm_ok=$(cat /sys/module/kvm_intel/parameters/nested)
    if [[ $kvm_ok == 'N' ]]; then
        msg+="- INFO: Intel Nested-Virtualization was enabled\n"
        sudo rmmod kvm-intel
        echo 'options kvm-intel nested=y' | sudo tee --append /etc/modprobe.d/dist.conf
        sudo modprobe kvm-intel
    fi
else
    kvm_ok=$(cat /sys/module/kvm_amd/parameters/nested)
    if [[ $kvm_ok == '0' ]]; then
        msg+="- INFO: AMD Nested-Virtualization was enabled\n"
        sudo rmmod kvm-amd
        echo 'options kvm-amd nested=1' | sudo tee --append /etc/modprobe.d/dist.conf
        sudo modprobe kvm-amd
    fi
fi
sudo modprobe vhost_net
enable_iommu

# Create Virtual Functions
for nic in $(sudo lshw -C network -short | grep Connection | awk '{ print $2 }'); do
    if [ -e "/sys/class/net/$nic/device/sriov_numvfs" ]  && grep -e up "/sys/class/net/$nic/operstate" > /dev/null ; then
        sriov_numvfs=$(cat "/sys/class/net/$nic/device/sriov_totalvfs")
        echo 0 | sudo tee "/sys/class/net/$nic/device/sriov_numvfs"
        echo "$sriov_numvfs" | sudo tee "/sys/class/net/$nic/device/sriov_numvfs"
        msg+="INFO - $sriov_numvfs SR-IOV Virtual Functions enabled on $nic"
    fi
done

${INSTALLER_CMD} "${packages[@]}"
if ! command -v pip; then
    curl -sL https://bootstrap.pypa.io/get-pip.py | sudo -H -E python
else
    sudo -H -E pip install --upgrade pip
fi
sudo -H -E pip install tox
if [[ ${HTTP_PROXY+x} = "x"  ]]; then
    vagrant plugin install vagrant-proxyconf
fi
if [ "$VAGRANT_DEFAULT_PROVIDER" == libvirt ]; then
    vagrant plugin install vagrant-libvirt
    sudo usermod -a -G $libvirt_group "$USER" # This might require to reload user's group assigments

    if command -v qemu-system-x86_64; then
        qemu_version=$(qemu-system-x86_64 --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')
        if _vercmp "${qemu_version}" '>' "2.6.0"; then
            # Permissions required to enable Pmem in QEMU
            sudo sed -i "s/#security_driver .*/security_driver = \"none\"/" /etc/libvirt/qemu.conf
            if [ -f /etc/apparmor.d/abstractions/libvirt-qemu ]; then
                sudo sed -i "s|  /{dev,run}/shm .*|  /{dev,run}/shm rw,|"  /etc/apparmor.d/abstractions/libvirt-qemu
            fi
            sudo systemctl restart libvirtd
        else
            # NOTE: PMEM in QEMU (https://nvdimm.wiki.kernel.org/pmem_in_qemu)
            msg+="WARN - PMEM support in QEMU is available since 2.6.0"
            msg+=" version. This host server is using the\n"
            msg+=" ${qemu_version} version. For more information about"
            msg+=" QEMU in Linux go to QEMU official website (https://wiki.qemu.org/Hosts/Linux)\n"
        fi
    fi

    # Start statd service to prevent NFS lock errors
    sudo systemctl enable rpc-statd
    sudo systemctl start rpc-statd

    if command -v firewall-cmd && systemctl is-active --quiet firewalld; then
        for svc in nfs rpc-bind mountd; do
            sudo firewall-cmd --permanent --add-service="${svc}" --zone=trusted
        done
        sudo firewall-cmd --set-default-zone=trusted
        sudo firewall-cmd --reload
    fi

    case ${ID,,} in
        ubuntu|debian)
        kvm-ok
        ;;
    esac
fi
echo -e "$msg"
