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

module timer_apb2_slave_tb;
    parameter ADDR_BITS = 12;
    parameter DATA_BITS = 8;
    parameter IO_LOGICAL = 8;

    localparam COUNTER_ADDR = 0;
    localparam COUNT_DOWN_VALUE_ADDR = 8;
    localparam CTRL_ADDR = 16;

    reg clk, rst, enable, mode;
    reg[63:0] counter;
    wire delay_pending;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;
    wire [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] logical_val;
    wire [IO_LOGICAL - 1:0] logical_drive;

    assign logical_in = {7'h0, enable};

    assign delay_pending = logical_val[1];

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    timer_apb2_slave timer_apb2_slave(
        .clk(clk),
        .rst(rst),

        .logical_in(logical_in),
        .logical_val(logical_val),
        .logical_drive(logical_drive),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    task get_counter;
        begin
            apb2_slave_tester.read(COUNTER_ADDR + 0, counter[0 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 1, counter[1 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 2, counter[2 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 3, counter[3 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 4, counter[4 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 5, counter[5 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 6, counter[6 * 8+:8]);
            apb2_slave_tester.read(COUNTER_ADDR + 7, counter[7 * 8+:8]);
        end
    endtask

    task set_delay;
        input reg[63:0] delay;
        begin
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 0, delay[0 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 1, delay[1 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 2, delay[2 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 3, delay[3 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 4, delay[4 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 5, delay[5 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 6, delay[6 * 8+:8]);
            apb2_slave_tester.write(COUNT_DOWN_VALUE_ADDR + 7, delay[7 * 8+:8]);
        end
    endtask

    initial begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always begin
        #5 clk = !clk;
    end

    initial begin
        clk = 0;

        // --- Timer Tests ---
        // -  Multi Count  -
        set_delay(0);
        apb2_slave_tester.write(CTRL_ADDR, 0);

        // Timer Reset
        @(negedge clk);
        rst = 1;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Disabled
        @(negedge clk);
        rst = 0;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Enabled
        @(negedge clk);
        enable = 1;
        #(100);
        @(negedge clk);
        enable = 0;
        get_counter();
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Disabled
        @(negedge clk);
        #(100);
        get_counter();
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Enabled
        @(negedge clk);
        enable = 1;
        #(100);
        @(negedge clk);
        enable = 0;
        get_counter();
        `util_assert_equal(20, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Reset
        @(negedge clk);
        rst = 1;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // --- Timer Tests ---
        // -  Single Count  -
        set_delay(0);
        apb2_slave_tester.write(CTRL_ADDR, 2);

        // Timer Reset
        @(negedge clk);
        rst = 1;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Disabled
        @(negedge clk);
        rst = 0;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Enabled
        @(negedge clk);
        enable = 1;
        #(100);
        @(negedge clk);
        enable = 0;
        get_counter();
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Disabled
        @(negedge clk);
        #(100);
        get_counter();
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Enabled
        @(negedge clk);
        enable = 1;
        #(100);
        @(negedge clk);
        enable = 0;
        get_counter();
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Reset
        @(negedge clk);
        rst = 1;
        enable = 0;
        #(100);
        get_counter();
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // --- Count Down Timer Tests ---
        set_delay(50);
        apb2_slave_tester.write(CTRL_ADDR, 1);

        @(negedge clk);
        rst = 1;
        enable = 0;
        #(100);
        `util_assert_equal(1, delay_pending);

        @(negedge clk);
        rst = 0;
        #(100);
        `util_assert_equal(1, delay_pending);

        @(negedge clk);
        enable = 1;
        `util_assert_equal(1, delay_pending);

        #(100);
        `util_assert_equal(1, delay_pending);

        #(400);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 0;

        #(100);
        $finish;

    end

endmodule
