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

module timer_tb;
    parameter MAIN_CLOCK = 10;
    reg clk;
    reg rst;
    reg enable;
    reg [7:0] ctrl;
    wire [63:0] counter;
    reg [63:0] count_down_value;
    wire delay_pending;

    timer timer(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .mode(ctrl[0]),
        .count_once(ctrl[1]),
        .count_down_value(count_down_value),
        .counter(counter),
        .delay_pending(delay_pending)
    );

    initial  begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always
        #(MAIN_CLOCK/2) clk = !clk;

    initial begin
        clk = 0;

        // Timer Tests
        // Multi count
        count_down_value = 50;
        ctrl = 8'b00000000;

        @(negedge clk);
        rst = 1;
        enable = 1;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 1;
        enable = 0;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 0;
        enable = 0;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 1;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 0;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 1;
        #100;
        `util_assert_equal(20, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 0;
        #100;
        `util_assert_equal(20, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 1;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Timer Tests
        // Single count
        count_down_value = 50;
        ctrl = 8'b00000010;

        @(negedge clk);
        rst = 1;
        enable = 1;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 1;
        enable = 0;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 0;
        enable = 0;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 1;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 0;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 1;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        enable = 0;
        #100;
        `util_assert_equal(10, counter);
        `util_assert_equal(0, delay_pending);

        @(negedge clk);
        rst = 1;
        #100;
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        // Count Down Timer Tests
        ctrl = 8'b00000001;
        count_down_value = 50;

        @(negedge clk);
        rst = 1;
        @(negedge clk);
        rst = 0;
        `util_assert_equal(50, counter);
        `util_assert_equal(1, delay_pending);

        #100;
        `util_assert_equal(50, counter);
        `util_assert_equal(1, delay_pending);

        @(negedge clk);
        enable = 1;

        #100
        `util_assert_equal(40, counter);
        `util_assert_equal(1, delay_pending);

        #400
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);

        #100
        `util_assert_equal(0, counter);
        `util_assert_equal(0, delay_pending);
        enable = 0;

        #100 $finish;
    end

endmodule
