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

module io_multiplexer_apb2_slave#(
        parameter IO_PHYSICAL = 16,
        parameter IO_LOGICAL = 8
    )
    (
        input wire clk,
        input wire rst,

        input wire [IO_PHYSICAL - 1:0] physical_in,
        output wire [IO_PHYSICAL - 1:0] physical_val,
        output wire [IO_PHYSICAL - 1:0] physical_drive,

        output wire [IO_LOGICAL - 1:0] logical_in,
        input wire [IO_LOGICAL - 1:0] logical_val,
        input wire [IO_LOGICAL - 1:0] logical_drive,

        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output wire [DATA_BITS - 1:0] PRDATA
   );

    localparam DATA_BITS = 8;
    localparam ADDR_BITS = 12;

    wire [(IO_PHYSICAL + IO_LOGICAL) * 8 - 1:0] phy_to_log_map;

    memory_apb2_slave #(.RW_SIZE(IO_PHYSICAL + IO_LOGICAL), .RO_SIZE(1), .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS), .RW_RESET_VAL(8'hFF)) memory_apb2_slave(
        .clk(clk),
        .rst(rst),
        .mem_rw_values(phy_to_log_map),
        .mem_ro_values(8'h0),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    /* Remap IO */
    pin_mux #(.IO_PHYSICAL(IO_PHYSICAL), .IO_LOGICAL(IO_LOGICAL)) pin_mux(
        .physical_in(physical_in),
        .physical_val(physical_val),
        .physical_drive(physical_drive),
        .physical_map(phy_to_log_map[IO_PHYSICAL * 8 - 1:0]),
        .logical_in(logical_in),
        .logical_val(logical_val),
        .logical_drive(logical_drive),
        .logical_map(phy_to_log_map[(IO_PHYSICAL + IO_LOGICAL) * 8 - 1:IO_PHYSICAL * 8])
    );

endmodule
