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

// UART tx module
//
// This modules acts as a UART transmitter.
//
// div - Baudrate divisor. Baudrate = clk / div
// parity_enable - 1 to enable parity 0 to disable it
// parity_odd_n_even - 1 to send odd parity, 0 to send even parity
// bit_count - Number of data bits to send. Valid values are 1 to 15
// stop_count - Number of stop bits to send. Valid values are 1 to 15
// data - Data to send. Must be set to the right value on the cycle strobe_send is high
// send - Signal to begin transmision.
//
// tx - TX pin to send data on
// ready - 0 when transmitting 1 when ready to send
// strobe_started - strobe indicating that transmission is starting
//
`define STATE_READY 0
`define STATE_START 1
`define STATE_DATA 2
`define STATE_PARITY 3
`define STATE_STOP 4

module uart_tx(
        input wire clk,
        input wire rst,
        input wire[15:0] div,
        input wire parity_enable,
        input wire parity_odd_n_even,
        input wire [3:0] bit_count,
        input wire [3:0] stop_count,
        input wire[15:0] data,
        input wire send,

        output wire tx,
        output wire ready,
        output wire strobe_started
    );

    reg [15:0] reg_div;
    reg [15:0] reg_div_count;
    reg reg_parity_enable;
    reg reg_parity_odd_n_even;
    reg [3:0] reg_bit_count;
    reg [3:0] reg_stop_count;
    reg [15:0] reg_data_shift;

    reg reg_tx;
    reg reg_ready;
    reg reg_strobe_started;

    reg [2:0] reg_state;

    assign tx = reg_tx;
    assign ready = reg_ready;
    assign strobe_started = reg_strobe_started;

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            reg_div <= 'hFFFF;
            reg_div_count <= 'hFFFE;
            reg_parity_enable <= 0;
            reg_parity_odd_n_even <= 0;
            reg_bit_count <= 8;
            reg_stop_count <= 1;
            reg_data_shift <= 0;
            reg_tx <= 1;
            reg_ready <= 1;
            reg_strobe_started <= 0;
            reg_state <= 0;
        end else begin

            // Strobe signal
            reg_strobe_started <= 0;

            // Run counter when active
            if (reg_state != `STATE_READY) begin
                if (reg_div_count > 0) begin
                    reg_div_count <= reg_div_count - 1;
                end else begin
                    reg_div_count <= reg_div - 1;
                end
            end

            // Start condition
            if ((reg_state == `STATE_READY) && send) begin
                reg_state <= `STATE_START;
                reg_ready <= 0;
                reg_div <= div;
                reg_div_count <= div - 1;
                reg_parity_enable <= parity_enable;
                reg_parity_odd_n_even <= parity_odd_n_even;
                reg_bit_count <= bit_count - 1;
                reg_stop_count <= stop_count - 1;
                reg_data_shift <= data;
                reg_strobe_started <= 1;
                reg_tx <= 0;
            end

            // State machine transitions
            if (reg_div_count == 0) begin
                if (reg_state == `STATE_START) begin
                    reg_state <= `STATE_DATA;
                    reg_data_shift <= reg_data_shift >> 1;
                    reg_parity_odd_n_even <= reg_parity_odd_n_even ^ reg_data_shift[0];
                    reg_tx <= reg_data_shift[0];
                end else if (reg_state == `STATE_DATA) begin
                    if (reg_bit_count > 0) begin
                        reg_bit_count <= reg_bit_count - 1;
                        reg_data_shift <= reg_data_shift >> 1;
                        reg_parity_odd_n_even <= reg_parity_odd_n_even ^ reg_data_shift[0];
                        reg_tx <= reg_data_shift[0];
                    end else begin
                        if (reg_parity_enable) begin
                            reg_state <= `STATE_PARITY;
                            reg_tx <= reg_parity_odd_n_even;
                        end else begin
                            reg_state <= `STATE_STOP;
                            reg_tx <= 1;
                        end
                    end
                end else if (reg_state == `STATE_PARITY) begin
                    reg_state <= `STATE_STOP;
                    reg_tx <= 1;
                end else if (reg_state == `STATE_STOP) begin
                    if (reg_stop_count > 0) begin
                        reg_stop_count <= reg_stop_count - 1;
                        reg_tx <= 1;
                    end else begin
                        if (send) begin
                            reg_state <= `STATE_START;
                            reg_div <= div;
                            reg_div_count <= div - 1;
                            reg_parity_enable <= parity_enable;
                            reg_parity_odd_n_even <= parity_odd_n_even;
                            reg_bit_count <= bit_count - 1;
                            reg_stop_count <= stop_count - 1;
                            reg_data_shift <= data;
                            reg_strobe_started <= 1;
                            reg_tx <= 0;
                        end else begin
                            reg_state <= `STATE_READY;
                            reg_ready <= 1;
                            reg_tx <= 1;
                        end
                    end
                end
            end
        end
    end

endmodule
