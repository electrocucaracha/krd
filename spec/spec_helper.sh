# shellcheck shell=sh
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2022
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
    : minimum_version "0.28.1"
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
    :
}

# This callback function will be invoked after core modules has been loaded.
spec_helper_configure() {
    : import 'support/custom_matcher'
}
