#!/bin/bash

#
# Copyright (c) 2019, Arm Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Check for a valid module name
if [ ${1: -3} != "_tb" ]; then
    echo "Error module \"$1\" missing \"_tb\" suffix"
    exit -1
fi

echo "Building \"$1\""
iverilog -Wall -W no-sensitivity-entire-array -g2001 -o top -f common.vc -s "$1" $1.v || exit $?

echo "Running \"$1\""
vvp top
result=$?

# Show UI if enabled
if [ -z "${NO_UI}" ]; then
    gtkwave top.vcd
fi

exit ${result}
