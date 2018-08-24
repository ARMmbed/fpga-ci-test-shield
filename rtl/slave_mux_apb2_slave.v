/*
 * Copyright (c) 2019, Arm Limited and affiliates.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// APB slave selector module
//
// This module interfaces with an APB master and selects
// and routes data from connected slave devices
//
// select - bits to select the peripheral
// PRDATA - APB data from the current peripheral
// PSELs - Peripheral select - Only one bit in this vector
//         will ever be set at the same time
// PRDATAs - Data from each of the peripherals
// PSEL - Peripheral select enable

module slave_mux_apb2_slave #(
        parameter SELECTOR_BITS = 4,
        parameter DATA_BITS = 8,
        parameter SLAVES =  2**SELECTOR_BITS
    )
    (
        input wire [SELECTOR_BITS - 1:0] select,
        input wire [SLAVES * DATA_BITS - 1:0] PRDATAs,
        input wire PSEL,
        output wire [DATA_BITS - 1:0] PRDATA,
        output wire [SLAVES - 1:0] PSELs
    );

    assign PSELs = 0 + PSEL << select;
    assign PRDATA = (select < SLAVES) ? PRDATAs[select * DATA_BITS+:DATA_BITS] : 0;

endmodule
