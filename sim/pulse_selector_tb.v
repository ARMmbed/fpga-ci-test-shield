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

module pulse_selector_tb;
    reg clk, rst;
    reg [3:0] pulses;
    wire [7:0] index;
    wire trigger;
    integer i;
    pulse_selector pulse_selector(
        .clk(clk),
        .rst(rst),
        .pulses(pulses),
        .index(index),
        .trigger(trigger)
    );

    initial begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always begin
        #5 clk = !clk;
    end

    initial begin
        clk = 0;
        rst = 0;
        pulses = 0;
    end

    task reset;
        input integer reset_time;
        begin
            @(negedge clk);
            rst = 1;
            #(reset_time);
            @(negedge clk);
            rst = 0;
        end
    endtask

    event terminate_sim;
    initial begin
        @terminate_sim;
        #200 $finish;
    end

    function integer msb_pos;
        input integer value;
        integer i;
        integer max_pos;
        begin
            max_pos = 0;
            for (i = 0; i < 32; i = i + 1) begin
                if (value & (1 << i)) begin
                    max_pos = i;
                end
            end
            msb_pos = max_pos;
        end
    endfunction

    task normal_operation_testcase;
        integer expected_index;
        begin
            reset(20);

            for (i = 1; i < (1 << 4); i = i + 1) begin
                // Start pulse on negative edge
                @(negedge clk);
                pulses = i;
                expected_index = msb_pos(pulses);

                // Finish pulse on negative edge
                @(negedge clk);
                pulses = 0;

                // Assert on positive edge
                @(posedge clk);
                `util_assert_equal(1, trigger);
                `util_assert_equal(expected_index, index);

                // Assert trigger is finished
                @(posedge clk);
                `util_assert_equal(0, trigger);
            end
        end
    endtask

    task random_testcase;
        begin
            reset(20);

            for (i = 0; i < 200; i = i + 1) begin
                // Start pulse on negative edge
                @(negedge clk);
                pulses = $random;

                // Give one cycle for the pulse to latch
                @(posedge clk);

                // Assert on second positive edge
                @(posedge clk);
                `util_assert_equal((0 || pulses), trigger);
                `util_assert_display((pulses === 0) || (index === msb_pos(pulses)), ("wrong pulse index. Expected %0d got %0d", msb_pos(pulses), index));
            end
        end
    endtask

    initial begin
        normal_operation_testcase();
        random_testcase();
        -> terminate_sim;
    end

endmodule
