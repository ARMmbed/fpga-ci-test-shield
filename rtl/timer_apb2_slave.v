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

// Timer/Count Down Timer module
//
// This module provides two functions:
// 1. Timer which counts elapsed time,
// 2. Count Down Timer which can be used a the delay generator.
//
// APB interface:
// Addr     Size    Name                                                                 Type
// +0       8       counter                                                              RW
// +8       8       count_down_value                                                     RW
// +16      1       ctrl                                                                 WO
// +17      1       reset request                                                        WO
//
module timer_apb2_slave #(
        parameter IO_LOGICAL = 8
    )
    (
        input wire clk,
        input wire rst,
        input wire [IO_LOGICAL - 1:0] logical_in,
        output wire [IO_LOGICAL - 1:0] logical_val,
        output wire [IO_LOGICAL - 1:0] logical_drive,

        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output reg [DATA_BITS - 1:0] PRDATA
    );

    localparam ADDR_BITS = 12;
    localparam DATA_BITS = 8;

    // 0 - FPGA Ticks Counter
    wire [63:0] counter;

    // 8 - Count Down Value
    reg [63:0] count_down_value;

    // 16 - Ctrl reg:
    //        - mode     Ctrl[0]: 0 - Timer, 1 - Count Down Timer
    //        - one_shot Ctrl[1]: 0 - measure sum of enable pulses, 1 - measure only first enable pulse (only for Timer mode)
    reg [7:0] ctrl;

    // 17 - Reset request
    reg [7:0] reset_request;

    reg [63:0] counter_reg;

    wire enable;
    wire delay_pending;
    wire reset;

    assign enable = logical_in[0];
    assign logical_val[0] = 1'b0;
    assign logical_drive[0] = 0;

    assign logical_val[1] = delay_pending;
    assign logical_drive[1] = 1;

    // Set unused outputs low
    assign logical_val[IO_LOGICAL - 1:2] = 0;
    assign logical_drive[IO_LOGICAL - 1:2] = 0;

    assign reset = ((rst == 1'b1) || (reset_request[0] == 1'b1));

    timer timer (
        clk,
        reset,
        enable,
        ctrl[0],
        ctrl[1],
        count_down_value,
        counter,
        delay_pending
    );

    wire negedge_enable;
    reg enable_prev;

    assign negedge_enable = (enable == 1'b0) && (enable_prev == 1'b1);

    always @(posedge clk) begin
        enable_prev <= enable;

        if (reset) begin
            counter_reg <= 0;
            reset_request <= 0;
        end else if (negedge_enable) begin
            counter_reg <= counter;
        end

        // APB interface
        if (PSEL) begin
            if (PWRITE && PENABLE) begin
                case (PADDR)
                    // Writeable values
                    0: counter_reg[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                    1: counter_reg[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                    2: counter_reg[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                    3: counter_reg[DATA_BITS * 3+:DATA_BITS] <= PWDATA;
                    4: counter_reg[DATA_BITS * 4+:DATA_BITS] <= PWDATA;
                    5: counter_reg[DATA_BITS * 5+:DATA_BITS] <= PWDATA;
                    6: counter_reg[DATA_BITS * 6+:DATA_BITS] <= PWDATA;
                    7: counter_reg[DATA_BITS * 7+:DATA_BITS] <= PWDATA;

                    8: count_down_value[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                    9: count_down_value[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                    10: count_down_value[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                    11: count_down_value[DATA_BITS * 3+:DATA_BITS] <= PWDATA;
                    12: count_down_value[DATA_BITS * 4+:DATA_BITS] <= PWDATA;
                    13: count_down_value[DATA_BITS * 5+:DATA_BITS] <= PWDATA;
                    14: count_down_value[DATA_BITS * 6+:DATA_BITS] <= PWDATA;
                    15: count_down_value[DATA_BITS * 7+:DATA_BITS] <= PWDATA;

                    16: ctrl <= PWDATA;
                    17: reset_request <= PWDATA;
                    default:;
                endcase
            end
            if (!PWRITE) begin

                case (PADDR)
                    // Readable values
                    0: PRDATA <= counter_reg[DATA_BITS * 0+:DATA_BITS];
                    1: PRDATA <= counter_reg[DATA_BITS * 1+:DATA_BITS];
                    2: PRDATA <= counter_reg[DATA_BITS * 2+:DATA_BITS];
                    3: PRDATA <= counter_reg[DATA_BITS * 3+:DATA_BITS];
                    4: PRDATA <= counter_reg[DATA_BITS * 4+:DATA_BITS];
                    5: PRDATA <= counter_reg[DATA_BITS * 5+:DATA_BITS];
                    6: PRDATA <= counter_reg[DATA_BITS * 6+:DATA_BITS];
                    7: PRDATA <= counter_reg[DATA_BITS * 7+:DATA_BITS];

                    8: PRDATA <= count_down_value[DATA_BITS * 0+:DATA_BITS];
                    9: PRDATA <= count_down_value[DATA_BITS * 1+:DATA_BITS];
                    10: PRDATA <= count_down_value[DATA_BITS * 2+:DATA_BITS];
                    11: PRDATA <= count_down_value[DATA_BITS * 3+:DATA_BITS];
                    12: PRDATA <= count_down_value[DATA_BITS * 4+:DATA_BITS];
                    13: PRDATA <= count_down_value[DATA_BITS * 5+:DATA_BITS];
                    14: PRDATA <= count_down_value[DATA_BITS * 6+:DATA_BITS];
                    15: PRDATA <= count_down_value[DATA_BITS * 7+:DATA_BITS];
                    default: PRDATA <= 0;
                endcase
            end
        end
    end
endmodule
