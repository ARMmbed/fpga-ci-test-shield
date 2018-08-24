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

// Memory interface
//
// This module provides an APB2 memory interface which supplies both
// read/write memory and read only memory. The read/write memory
// can be read by other parts of the system and the read only
// memory can be sent values by other parts of the system.
//
module memory_apb2_slave #(
        parameter ADDR_BITS = 4,
        parameter DATA_BITS = 4,
        parameter RW_SIZE = 16,
        parameter RO_SIZE = 16,
        parameter RW_RESET_VAL = 0
    )
    (
        input wire clk,
        input wire rst,
        output reg [RW_SIZE * DATA_BITS - 1:0] mem_rw_values,
        input wire [RO_SIZE * DATA_BITS  - 1:0] mem_ro_values,
        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output reg [DATA_BITS - 1:0] PRDATA
    );

    localparam TOTAL_SIZE = RW_SIZE + RO_SIZE;

    wire [(RW_SIZE + RO_SIZE) * DATA_BITS - 1:0] mem;

    assign mem = {mem_ro_values, mem_rw_values};

    always @(posedge clk) begin
        if (rst) begin
            mem_rw_values <= {RW_SIZE{RW_RESET_VAL[DATA_BITS - 1:0]}};
            PRDATA <= 0;
        end else if (PSEL) begin
            if (PWRITE) begin
                if (PENABLE && (PADDR < RW_SIZE)) begin
                    mem_rw_values[PADDR * DATA_BITS+:DATA_BITS] <= PWDATA;
                end
            end else begin
                PRDATA <= PADDR < TOTAL_SIZE ? mem[PADDR * DATA_BITS+:DATA_BITS] : 0;
            end
        end
    end

endmodule
