#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021,2023
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=tests/_functions.sh
source _functions.sh

function _run_test {
    local test="$1"
    # shellcheck disable=SC2064
    trap "./krd_command.sh -a uninstall_${test}" RETURN

    info "+++++ Starting $test test..."
    ./krd_command.sh -a "install_${test}"
    pushd tests
    bash "${test}.sh"
    popd
    info "+++++ $test test completed"
}

cd ..
for test in "$@"; do
    _run_test "$test"
done
