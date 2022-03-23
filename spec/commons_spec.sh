#shellcheck shell=sh
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2022
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

Describe '_commons.sh'
    Include ./_commons.sh

    Describe '_vercmp()'
        Parameters
            '1.1.1' '==' '1.1.1' success
            '1.1.1' '==' '1.1.0' failure
            '1.1.0' '<'  '1.1.1' success
            '1.1.1' '<'  '1.1.0' failure
            '1.1.1' '<'  '1.1.1' failure
            '1.1.1' '<=' '1.1.1' success
            '1.1.0' '<=' '1.1.1' success
            '1.1.1' '<=' '1.1.0' failure
            '1.1.1' '>'  '1.1.0' success
            '1.1.0' '>'  '1.1.1' failure
            '1.1.1' '>'  '1.1.1' failure
            '1.1.1' '>=' '1.1.0' success
            '1.1.1' '>=' '1.1.1' success
            '1.1.0' '>=' '1.1.1' failure
        End
        It 'performs comparation'
            When call _vercmp "$1" "$2" "$3"
            The status should be "$4"
        End
        It 'raises error when specified an invalid operator'
            When run _vercmp '1.0.0' '!=' '2.0.0'
            The stdout should equal "unrecognised op: !="
            The status should be failure
        End
    End
End
