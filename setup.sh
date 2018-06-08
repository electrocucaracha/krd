#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

vagrant_version=2.1.1

function usage {
    cat <<EOF
usage: $0 -p <PROVIDER>
Installation of vagrant and its dependencies in Linux OS

Argument:
    -p  Vagrant provider
EOF
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

case $provider in
    "virtualbox" | "libvirt" )
        export VAGRANT_DEFAULT_PROVIDER=${provider}
        ;;
    * )
        usage
        exit 1
esac
source /etc/os-release || source /usr/lib/os-release

libvirt_group="libvirt"
packages=()
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"

    # Vagrant installation
    vagrant_pgp="pgp_keys.asc"
    wget -q https://keybase.io/hashicorp/$vagrant_pgp
    wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.rpm
    gpg --quiet --with-fingerprint $vagrant_pgp
    sudo rpm --import $vagrant_pgp
    sudo rpm --checksig vagrant_${vagrant_version}_x86_64.rpm
    sudo rpm --install vagrant_${vagrant_version}_x86_64.rpm
    rm vagrant_${vagrant_version}_x86_64.rpm
    rm $vagrant_pgp

    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
        wget -q http://download.virtualbox.org/virtualbox/rpm/opensuse/$VERSION/virtualbox.repo -P /etc/zypp/repos.d/
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

    # Vagrant installation
    wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.deb
    sudo dpkg -i vagrant_${vagrant_version}_x86_64.deb
    rm vagrant_${vagrant_version}_x86_64.deb

    case $VAGRANT_DEFAULT_PROVIDER in
        virtualbox)
        echo "deb http://download.virtualbox.org/virtualbox/debian trusty contrib" >> /etc/apt/sources.list
        wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
        wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
        packages+=(virtualbox-5.1 dkms)
        ;;
        libvirt)
        # vagrant-libvirt dependencies
        packages+=(qemu libvirt-bin ebtables dnsmasq libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev)
        # NFS
        packages+=(nfs-kernel-server)
        ;;
    esac
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(which dnf || which yum)
    sudo $PKG_MANAGER updateinfo
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"

    # Vagrant installation
    wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.rpm
    $INSTALLER_CMD vagrant_${vagrant_version}_x86_64.rpm
    rm vagrant_${vagrant_version}_x86_64.rpm

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

${INSTALLER_CMD} ${packages[@]}
if [ $http_proxy ]; then
    vagrant plugin install vagrant-proxyconf
fi
if [ $VAGRANT_DEFAULT_PROVIDER == libvirt ]; then
    vagrant plugin install vagrant-libvirt
    sudo usermod -a -G $libvirt_group $USER
    if [ $http_proxy ]; then
        virsh net-update default delete ip-dhcp-range "<range start='192.168.122.2' end='192.168.122.254'/>" --live --config
        virsh net-update default add ip-dhcp-range "<range start='192.168.122.2' end='192.168.122.28'/>" --live --config
    fi
    sudo systemctl restart libvirtd
fi
