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

source _functions.sh
source _installers.sh
source _chart_installers.sh
source _uninstallers.sh

if [[ $KRD_DEBUG == "true" ]]; then
    set -o xtrace
fi

if ! sudo -n "true"; then
    echo ""
    echo "passwordless sudo is needed for '$(id -nu)' user."
    echo "Please fix your /etc/sudoers file. You likely want an"
    echo "entry like the following one..."
    echo ""
    echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

function join_by {
    local delimiter=${1-}
    local items=${2-}
    if shift 2; then
        printf %s "$items" "${@/#/$delimiter}"
    fi
}

applications=(k8sgpt-operator local-ai kube-monkey haproxy)
valid_options=$(find . -maxdepth 1 -name "_*.sh" -exec grep -o "^function [a-z].*" {} + | awk '{printf "%s|", $2}')
valid_options+="install_$(join_by '|install_' "${applications[@]}")|uninstall_$(join_by '|uninstall_' "${applications[@]}")|"

function usage {
    cat <<EOF
Usage: $0 [-a <${valid_options%?}>]
EOF
}

while getopts ":a:" OPTION; do
    case $OPTION in
    a)
        eval "case \$OPTARG in
                ${valid_options%?})
                    echo \"::group::Running \$OPTARG...\"
                    [[ \" ${applications[*]} \" =~ [[:space:]]\${OPTARG#*install_}[[:space:]] ]] && _\${OPTARG/install_/install_app } || \$OPTARG
                    if [ \"\$KRD_ENABLE_TESTS\" == \"true\" ] && [ -f \$KRD_FOLDER/tests/\${OPTARG#*install_}.sh ]  ; then
                        pushd \$KRD_FOLDER/tests
                        bash \${OPTARG#*install_}.sh
                        popd
                    fi
                    echo \"::endgroup::\"
                ;;
                *)
                    echo Invalid action
                    usage
                    exit 1
                esac"
        ;;
    *)
        usage
        ;;
    esac
done
