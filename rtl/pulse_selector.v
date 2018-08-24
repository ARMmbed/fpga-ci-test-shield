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

// Pulse selector
//
// This module takes a vector of pulses and outputs
// a trigger and the index of the most recent pulse.
//
// Guarantees:
// -trigger and index are valid on the cycle after the pulse
// -index remains unchanged until a new pulse or a reset
// -if multiple bits are pending then the most significant is used

module pulse_selector #(
        parameter PULSE_COUNT = 4
    )
    (
        input wire clk,
        input wire rst,
        input wire [PULSE_COUNT - 1:0] pulses,
        output reg [7:0] index,
        output reg trigger
    );

    integer i;

    function integer msb_pos(
            input integer value
        );

        integer max_pos;
        integer _value;
        begin
            _value = value;
            max_pos = 0;
            repeat (PULSE_COUNT) begin
                _value = _value >> 1;
                if (_value > 0) begin
                    max_pos = max_pos + 1;
                end
            end
            msb_pos = max_pos;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            index <= ~0;
            trigger <= 0;
        end else begin
            if (pulses) begin
                index <= msb_pos(pulses);
            end
            trigger <= 0 || pulses;
        end
    end
endmodule
