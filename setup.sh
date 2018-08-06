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

vagrant_version=2.1.2
if ! $(vagrant version &>/dev/null); then
    enable_vagrant_install=true
else
    if [[ "$vagrant_version" != "$(vagrant version | awk 'NR==1{print $3}')" ]]; then
        enable_vagrant_install=true
    fi
fi

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
source /etc/os-release || source /usr/lib/os-release

libvirt_group="libvirt"
packages=()
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"

    # Vagrant installation
    if [[ "${enable_vagrant_install+x}" ]]; then
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
    if [[ "${enable_vagrant_install+x}" ]]; then
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
    if [[ "${enable_vagrant_install+x}" ]]; then
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

if ! which pip; then
    curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
fi
sudo pip install --upgrade pip
sudo pip install tox

${INSTALLER_CMD} ${packages[@]}
if [[ ${http_proxy+x} ]]; then
    vagrant plugin install vagrant-proxyconf
fi
if [ $VAGRANT_DEFAULT_PROVIDER == libvirt ]; then
    vagrant plugin install vagrant-libvirt
    sudo usermod -a -G $libvirt_group $USER # This might require to reload user's group assigments
    sudo systemctl restart libvirtd
fi
