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

// This is a utility module to record signals
//
// It samples a signal on the rising edge of every clock
// cycle and records any changes to its value.
//
// Utility variables
// events - The number of events that have occured
// cycle - the number of clock cycles which have occurred
//
// Utility functions/tasks
// get_value(index) - Get the event value at the index
// get_time(index) - Get the event timestamp at the index
// get_cycle(index) - Get the event clock cycle at the index
// reset() - Reset all counters and event history
//
// clk - Clock signal use for sampling on the postive edge
// signal - Signal to record
`include "util.v"

module signal_history #(
        parameter MAX_ENTRIES = 1000,
        parameter WIDTH = 1
    )
    (
        input wire clk,
        input wire [WIDTH - 1:0] signal
    );

    // Number of events recorded
    integer events;

    // Number of cycles recorded
    integer cycle;

    function [WIDTH - 1:0] get_value;
        input integer index;
        begin
            get_value = values[check_index(index)];
        end
    endfunction

    function time get_time;
        input integer index;
        begin
            get_time = times[check_index(index)];
        end
    endfunction

    function integer get_cycle;
        input integer index;
        begin
            get_cycle = cycles[check_index(index)];
        end
    endfunction

    function [WIDTH - 1:0] value_at_cycle;
        input integer cycle_to_find;
        reg [WIDTH - 1:0] return_value;
        integer i;
        begin
            i = 0;
            return_value = initial_value;
            while ((i < events) && (cycles[i] <= cycle_to_find)) begin
                return_value = values[i];
                i = i + 1;
            end
            value_at_cycle = return_value;
        end
    endfunction

    task reset;
        integer i;
        begin
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
                values[i] = 'hx;
                times[i] = 'hx;
                cycles[i] = 'hx;
            end
            initial_value = signal;
            value = initial_value;
            cycle = 0;
            events = 0;
        end
    endtask

    reg [WIDTH - 1:0] values[0:MAX_ENTRIES - 1];
    time times[0:MAX_ENTRIES - 1];
    integer cycles[0:MAX_ENTRIES - 1];
    reg [WIDTH - 1:0] initial_value;
    reg [WIDTH - 1:0] value;

    initial begin
        reset();
    end

    always @(posedge clk) begin
        if (value != signal) begin
            `util_assert(events < MAX_ENTRIES);
            if (events < MAX_ENTRIES) begin
                values[events] = signal;
                times[events] = $time;
                cycles[events] = cycle;
            end
            events = events + 1;
            value = signal;
        end

        cycle = cycle + 1;
    end

    function integer check_index;
        input integer index;
        begin
            index = index >= 0 ? index : index + events;
            `util_assert((0 <= index) && (index < events));
            check_index = ((0 <= index) && (index < events)) ? index : 0;
        end
    endfunction

endmodule
