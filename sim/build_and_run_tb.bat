::
:: Copyright (c) 2019, Arm Limited and affiliates.
:: SPDX-License-Identifier: Apache-2.0
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
:: http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
::

@echo off

set module=%1
if "%module:~-3%" neq "_tb" (
    echo Error module "%module%" missing "_tb" suffix
    exit /b -1
)

echo Building "%module%"
iverilog -Wall -W no-sensitivity-entire-array -g2001 -o top -f common.vc -s %module% %module%.v || exit /b

echo Running "%module%"
vvp top

if "%NO_UI%"=="" gtkwave top.vcd || exit /b
