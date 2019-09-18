#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail

# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    rhel|centos|fedora)
        PKG_MANAGER=$(command -v dnf || command -v yum)
        INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
        $INSTALLER_CMD epel-release
        $INSTALLER_CMD glib2-devel libfdt-devel pixman-devel zlib-devel wget python3 libpmem-devel numactl-devel
        sudo -H -E "${PKG_MANAGER}" -q -y group install "Development Tools"
    ;;
esac

qemu_version=4.1.0
qemu_tarball="qemu-${qemu_version}.tar.xz"

wget -c "https://download.qemu.org/$qemu_tarball"
tar xvf "$qemu_tarball"
rm -rf "$qemu_tarball"
pushd "qemu-${qemu_version}" || exit
./configure --target-list=x86_64-softmmu --enable-libpmem --enable-numa --enable-kvm
make
sudo make install
popd || exit
rm -rf "qemu-${qemu_version}"
