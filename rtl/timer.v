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

// Timer module
//
// This module counts elapsed time or performs the delay
//
// FPGA Timer resolution is 10 ns: 1 timer tick corresponds to 10 ns.
//
// 1. MODE_TIMER
//    Timer counts `clk` ticks when `enable` signal is high.
//
// 1. MODE_COUNT_DOWN_TIMER
//    Count Down Timer is designed to generate delays. In this mode on reset the
//    `count_down_value` is loaded to `counter` reg and `delay_pending` signal goes high.
//    When `enable` becomes high, then Count Down Timer decreases the `counter` reg by 1 on each `clk` raising edge.
//    When `counter` reg reaches 0, then `delay_pending` goes low indicating that the delay operation is finished.
//
// mode - MODE_TIMER: measure elapsed time, MODE_COUNT_DOWN_TIMER: perform delay
// enable - when 1 Timer counts rising clk edges or perform the delay (depending on mode)
// count_once - When 1 then only first pulse of the `enable` signal is measured
// count_down_value - tick count which represents the delay to be performed
// counter - current counter value
// delay_pending - a signal which indicates if the programmed delay is still pending
//

module timer
    (
        input wire clk,
        input wire rst,
        input wire enable,
        input wire mode,
        input wire count_once,
        input wire[63:0] count_down_value,
        output reg[63:0] counter,
        output wire delay_pending
    );

    localparam MODE_TIMER              = 2'b00;  // Measure elapsed time
    localparam MODE_COUNT_DOWN_TIMER   = 2'b01;  // Perform delay
    
    reg counting_enabled;
    reg enable_prev;
    wire negedge_enable;
    
    assign delay_pending = (mode == MODE_TIMER ? 0 : (counter == 0 ? 0 : 1));
    assign negedge_enable = (enable == 1'b0) && (enable_prev == 1'b1);

    // Sequential logic
    always @(posedge clk) begin
        enable_prev <= enable;
        if (rst == 1'b1) begin
            // Reset
            if (mode == MODE_TIMER) begin
                counter <= 0;
                counting_enabled <= 1;
            end else begin
                counter <= count_down_value;
            end
        end else begin
            if (mode == MODE_TIMER) begin
                if (enable == 1'b1 && counting_enabled == 1'b1) begin
                    counter <= counter + 1;
                end
                
                if (count_once == 1'b1 && negedge_enable == 1'b1) begin
                    counting_enabled <= 1'b0;
                end
                
            end else begin
                if (enable == 1'b1 && counter > 0) begin
                    counter <= counter - 1;
                end
            end
        end
    end
endmodule
