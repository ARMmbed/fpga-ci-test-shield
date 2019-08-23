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

// UART rx module
//
// This modules acts as a UART receiver.
//
// enable - Enables reception of data. This must be false when changing settings
// div - Baudrate divisor. Baudrate = clk / div
// parity_enable - 1 to enable parity checking 0 to disable it
// parity_odd_n_even - 1 to check for odd parity, 0 to check for even parity
// bit_count - Number of data bits to receive. Valid values are 1 to 15
// stop_count - Number of stop bits to check for. Valid values are 1 to 15
//
// rx - value of the RX pin
//
// strobe_start - strobe indicating that reception has started
// strobe_sample - strobe indicating that the RX line has been sampled
// strobe_transition - strobe indicating that the RX line may transition
// strobe_done - strobe indicating that reception has finished and that
//               the signals data, line_break, stop_error and other_error
//               are valid
// data - Data received - only valid when strobe_done is high
// data_valid - Data was filled with new contents - only valid when strobe_done is high
// parity_error - The transfer had an invalid parity value - only valid when strobe_done is high
// stop_error - There were not enough stop bits - only valid when strobe_done is high
// other_error - Frame was invalid - only valid when strobe_done is high
//

`define STATE_IDLE 0
`define STATE_START 1
`define STATE_DATA 2
`define STATE_PARITY 3
`define STATE_STOP 4

module uart_rx(
        input wire clk,
        input wire rst,
        input wire enable,
        input wire[15:0] div,
        input wire parity_enable,
        input wire parity_odd_n_even,
        input wire [3:0] bit_count,
        input wire [3:0] stop_count,

        input wire rx,

        output wire strobe_done,
        output wire[15:0] data,
        output wire parity_error,
        output wire stop_error,
        output wire other_error
    );

    wire strobe_start;
    wire strobe_sample;
    wire strobe_transition;

    reg rx_prev;
    reg [15:0] div_count;
    reg [3:0] bit_count_reg;
    reg [3:0] stop_count_reg;
    reg strobe_done_reg;
    reg [15:0] data_reg;
    reg data_parity;
    reg parity_error_reg;
    reg stop_error_reg;
    reg other_error_reg;
    reg [2:0] state;

    integer i;

    // Combinational logic
    assign strobe_start = enable && (state == `STATE_IDLE) && (rx_prev == 1'b1) && (rx == 1'b0);
    assign strobe_sample = (state != `STATE_IDLE) && (div_count == div[15:1]);
    assign strobe_transition = (state != `STATE_IDLE) && (div_count == 0);
    assign strobe_done = strobe_done_reg;
    assign data = data_reg;
    assign parity_error = parity_error_reg;
    assign stop_error = stop_error_reg;
    assign other_error = other_error_reg;

    // Sequential logic
    always @(posedge clk) begin
        rx_prev <= rx;

        // strobe registers
        strobe_done_reg <= 0;

        if ((rst == 1'b1) || (enable == 0)) begin
            // Reset

            div_count <= 0;
            bit_count_reg <= 0;
            stop_count_reg <= 0;
            strobe_done_reg <= 0;
            data_reg <= 0;
            data_parity <= 0;
            parity_error_reg <= 0;
            stop_error_reg <= 0;
            other_error_reg <= 0;
            state <= `STATE_IDLE;

        end else begin

            // Edge of start
            if (strobe_start) begin
                div_count <= 1;
                bit_count_reg <= 0;
                stop_count_reg <= 0;
                data_reg <= 0;
                data_parity <= 0;
                parity_error_reg <= 0;
                stop_error_reg <= 0;
                other_error_reg <= 0;
                state <= `STATE_START;
            end

            // Run counter when not idle
            if (state != `STATE_IDLE) begin
                if (div_count + 1 >= div) begin
                    div_count <= 0;
                end else begin
                    div_count <= div_count + 1;
                end
            end

            if (strobe_sample) begin
                if (state == `STATE_START) begin
                    if (rx == 0) begin
                        state <= `STATE_DATA;
                    end else begin

                        // Error - not a valid start
                        data_reg <= 0;
                        other_error_reg <= 1;
                        strobe_done_reg <= 1;
                        state <= `STATE_IDLE;
                    end
                end else if (state == `STATE_DATA) begin
                    data_reg[bit_count_reg] <= rx;
                    data_parity <= data_parity ^ rx;
                    if (bit_count_reg + 1 >= bit_count) begin
                        bit_count_reg <= 0;
                        state <= parity_enable ? `STATE_PARITY : `STATE_STOP;
                    end else begin
                        bit_count_reg <= bit_count_reg + 1;
                    end
                end else if (state == `STATE_PARITY) begin
                    parity_error_reg <= (rx ^ data_parity) == parity_odd_n_even ? 0 : 1;
                    state <= `STATE_STOP;
                end else if (state == `STATE_STOP) begin
                    if (rx == 1) begin

                        if (stop_count_reg + 1 >= stop_count) begin
                            stop_count_reg <= 0;

                            // Valid transfer
                            strobe_done_reg <= 1;
                            state <= `STATE_IDLE;

                        end else begin
                            stop_count_reg <= stop_count_reg + 1;
                        end
                    end else begin

                        // Too few stop bytes
                        // data is still valid though
                        stop_error_reg <= 1;
                        strobe_done_reg <= 1;
                        state <= `STATE_IDLE;
                    end


                end
            end
        end
    end

endmodule
