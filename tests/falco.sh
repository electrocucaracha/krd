#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2021
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
# shellcheck source=tests/_assertions.sh
source _assertions.sh

info "===== Test started ====="
trap 'info "===== Test completed ====="' EXIT

falco_log="$(kubectl logs -l app.kubernetes.io/name=falco -n falco-system -c falco)"
assert_non_empty "$falco_log" "Falco's logs are disabled"
assert_contains "$falco_log" 'Starting health webserver' "Falco internal server hasn't started"
