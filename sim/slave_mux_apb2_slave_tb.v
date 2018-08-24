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

`include "util.v"

module slave_mux_apb2_slave_tb;
    localparam SELECTOR_BITS = 5;
    localparam DATA_BITS = 9;
    localparam PERIPHERALS = 1 << SELECTOR_BITS;
    reg [SELECTOR_BITS - 1:0] select;
    reg [PERIPHERALS * DATA_BITS - 1:0] PRDATAs;
    reg PSEL;
    wire [DATA_BITS - 1:0] PRDATA;
    wire [PERIPHERALS - 1:0] PSELs;

    slave_mux_apb2_slave #(.SELECTOR_BITS(SELECTOR_BITS), .DATA_BITS(DATA_BITS)) slave_mux_apb2_slave(
        .select(select),
        .PRDATAs(PRDATAs),
        .PSEL(PSEL),
        .PRDATA(PRDATA),
        .PSELs(PSELs)
    );

    initial begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    initial begin
        select = 0;
        PRDATAs = 'hx;
        PSEL = 0;
    end

    event terminate_sim;
    initial begin
        @terminate_sim;
        #200 $finish;
    end

    task normal_operation_testcase;
        integer i;
        reg [DATA_BITS - 1:0] expected;
        begin
            for (i = 0; i < PERIPHERALS; i = i + 1) begin
                expected = $random;
                select = i;
                PSEL = 0;
                PRDATAs = 'hx;
                PRDATAs[i * DATA_BITS+:DATA_BITS] = expected;
                #1;

                `util_assert_equal(expected, PRDATA);
                `util_assert_equal(0, PSELs);

                PSEL = 1;
                #1

                `util_assert_equal(expected, PRDATA);
                `util_assert_equal(1 << select, PSELs);
            end
        end
    endtask

    initial begin
        normal_operation_testcase();
        -> terminate_sim;
    end

endmodule
