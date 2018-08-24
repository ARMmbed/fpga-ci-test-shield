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

// This is a utility module to test uart
//
// This allows UART data to be sent and received
// for testing UART.
//
// Common functions/tasks
// set_period(period) - Set the period per bit to use for TX and RX.
// set_parity(enable, odd_n_even) - Set the parity to use for TX and RX.
// set_data_bits(datas) - Set the number of data bits to use for TX and RX.
// set_stop_bits(stops) - Set the number of stop bits to use for TX and RX.
//
// Transmit functions/tasks
// send(value) - Send the given value in a valid frame on the TX line.
// send_raw(value, bits) - Send raw bits on the TX line. No start, parity or stop
//                         bits are included in the data.
// send_pulse(duration) - Send a low pulse for the given duration
//
// Receive functions/tasks
// receive_count - Integer holding the number of transfers received
// receive_start() - Clear received values and start reception
// receive_stop() - Stop reception. If a byte is being received this blocks until it is complete
// receive_value(index) - Get the value received at the given index.
//                        Index 0 is of the first transfers received since receive_start
// receive_value_raw(index) - Get the raw value received at the given index. Index 0 is of the
//                            first transfers received since receive_start. The raw value includes
//                            all bits including start, parity, and stop.
// receive_value_valid(index) - Return 1 if the value at the index has correct start, parity and stop bits
//                              otherwise return 0.
//
`include "util.v"

module uart_tester #(
        parameter MAX_ENTRIES = 100,
        parameter MAX_BITS = 32
    )
    (
        input wire clk,
        input wire rst,
        output wire tx,
        input wire rx
    );

    task set_period;
        input integer new_period;
        begin
            `util_assert_equal(0, rx_active);
            period = new_period;
        end
    endtask

    task set_parity;
        input reg enable;
        input reg odd_n_even;
        begin
            `util_assert_equal(0, rx_active);
            parity_enable = enable;
            parity_odd_n_even = odd_n_even;
        end
    endtask

    task set_data_bits;
        input integer datas;
        begin
            `util_assert_equal(0, rx_active);
            data_bits = datas;
        end
    endtask

    task set_stop_bits;
        input integer stops;
        begin
            `util_assert_equal(0, rx_active);
            stop_bits = stops;
        end
    endtask

    task send;
        input integer value;
        integer raw_value;
        integer i;
        reg parity;
        begin
            parity = parity_odd_n_even;
            for (i = 0; i < data_bits; i = i + 1) begin
                parity = parity ^ value[i];
            end

            raw_value = 0;
            raw_value = (raw_value << stop_bits) | ((1 << stop_bits) - 1);
            raw_value = parity_enable ? (raw_value << 1) | parity : raw_value;
            raw_value = (raw_value << data_bits) | value;
            raw_value = (raw_value << 1) | 0;
            send_raw(raw_value, 1 + data_bits + (parity_enable ? 1 : 0) + stop_bits);
        end
    endtask

    task send_raw;
        input integer value;
        input integer value_bits;

        begin
            repeat (value_bits) begin
                tx_async = value[0];
                value = value >> 1;
                #(period);
            end
        end
    endtask

    task send_pulse;
        input integer duration;

        begin
            tx_async = 0;
            #(duration);
            tx_async = 1;
        end
    endtask

    integer receive_count;

    task receive_start;
        integer i;
        begin
            `util_assert_equal(0, rx_enabled);
            receive_count = 0;
            rx_enabled = 1;
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
                rx_values[i] = 'hx;
                rx_values_raw[i] = 'hx;
                rx_values_valid[i] = 'hx;
            end
        end
    endtask

    task receive_stop;
        begin
            `util_assert_equal(1, rx_enabled);
            rx_enabled = 0;
            wait (rx_active == 0);
        end
    endtask

    function [MAX_BITS - 1:0] receive_value;
        input integer index;
        begin
            `util_assert((0 <= index) && (index < receive_count));
            receive_value = rx_values[index];
        end
    endfunction

    function [MAX_BITS - 1:0] receive_value_raw;
        input integer index;
        begin
            `util_assert((0 <= index) && (index < receive_count));
            receive_value_raw = rx_values_raw[index];
        end
    endfunction

    function reg receive_value_valid;
        input integer index;
        begin
            `util_assert((0 <= index) && (index < receive_count));
            receive_value_valid = rx_values_valid[index];
        end
    endfunction

    integer period = 100;
    reg parity_enable = 0;
    reg parity_odd_n_even = 0;
    integer data_bits = 8;
    integer stop_bits = 1;

    reg tx_sync = 1;
    reg tx_async = 1;

    assign tx = tx_sync;

    always @(posedge clk) begin
        tx_sync <= tx_async;
    end

    event rx_event;
    reg rx_enabled = 0;
    reg rx_active = 0;
    reg [MAX_BITS - 1:0] rx_values[MAX_ENTRIES - 1:0];
    reg [MAX_BITS - 1:0] rx_values_raw[MAX_ENTRIES - 1:0];
    reg rx_values_valid[MAX_ENTRIES - 1:0];
    always begin: rx_thread
        integer i;
        integer raw_bit_count;
        reg [MAX_BITS - 1:0] raw_bits;
        integer offset;
        reg start_valid;
        reg parity_valid;
        reg stop_valid;
        reg local_parity;

        while (rx || !rx_enabled) begin
            if (!rx_enabled) begin
                rx_active = 0;
                wait (rx_enabled);
                rx_active = 1;
            end
            raw_bit_count = 1 + data_bits + (parity_enable ? 1 : 0) + stop_bits;
            wait (!rx || !rx_enabled);
        end
        raw_bits = 0;

        // Wait half a clock period before sampling
        #(period / 2);
        raw_bits[i] = rx;

        // Receive the full raw value
        for (i = 1; i < raw_bit_count; i = i + 1) begin
            #(period);
            raw_bits[i] = rx;
        end

        // Store the value
        if (receive_count < MAX_ENTRIES) begin
            // Check start
            start_valid = raw_bits[0] == 0 ? 1 : 0;

            // Check parity
            local_parity = 0;
            offset = 1;
            if (parity_enable) begin
                for (i = offset; i < offset + data_bits + 1; i = i + 1) begin
                    local_parity = local_parity ^ raw_bits[i];
                end
                parity_valid = local_parity == parity_odd_n_even ? 1 : 0;
            end else begin
                parity_valid = 1;
            end

            // Check stop
            offset = 1 + data_bits + (parity_enable ? 1 : 0);
            stop_valid = 1;
            for (i = offset; i < offset + stop_bits; i = i + 1) begin
                stop_valid = stop_valid & raw_bits[i];
            end

            // Store values
            rx_values[receive_count] = (raw_bits >> 1) & ((1 << data_bits) - 1);
            rx_values_raw[receive_count] = raw_bits;
            rx_values_valid[receive_count] = start_valid & parity_valid & stop_valid;
        end
        receive_count = receive_count + 1;
        -> rx_event;
    end
endmodule
