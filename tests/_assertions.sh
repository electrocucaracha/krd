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
KRD_DEBUG="${KRD_DEBUG:-false}"
if [[ "${KRD_DEBUG}" == "true" ]]; then
    set -o xtrace
fi

# shellcheck source=tests/_utils.sh
source _utils.sh

# assert_non_empty() - This assertion checks if the expected value is not empty
function assert_non_empty {
    local input=$1
    local error_msg=$2

    if [[ "$KRD_DEBUG" == "true" ]]; then
        debug "NonEmpty Assertion - value: $1"
    fi
    if [ -z "$input" ]; then
        error "$error_msg"
    fi
}

# assert_are_equal() - This assertion checks if the inputs are equal
function assert_are_equal {
    local input=$1
    local expected=$2
    local error_msg=${3:-"got $input, want $expected"}

    if [[ "$KRD_DEBUG" == "true" ]]; then
        debug "Are equal Assertion - value: $1 expected: $2"
    fi
    if [ "$input" != "$expected" ]; then
        error "$error_msg"
    fi
}

# assert_are_not_equal() - This assertion checks if the inputs are not equal
function assert_are_not_equal {
    local input=$1
    local expected=$2
    local error_msg=$3

    if [[ "$KRD_DEBUG" == "true" ]]; then
        debug "Are not equal Assertion - value: $1 expected: $2"
    fi
    if [ "$input" == "$expected" ]; then
        error "$error_msg"
    fi
}

# assert_contains() - This assertion checks if the input contains another value
function assert_contains {
    local input=$1
    local expected=$2
    local error_msg=${3:-"$input doesn't contains $expected"}

    if [[ "$KRD_DEBUG" == "true" ]]; then
        debug "Contains Assertion - value: $1 expected: $2"
    fi
    if [[ "$input" != *"$expected"* ]]; then
        error "$error_msg"
    fi
}
