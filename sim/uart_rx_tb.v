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

`define HISTORY_DEPTH 10

module uart_rx_tb;
    reg clk, rst;
    reg enable;
    reg [15:0] div;
    reg parity_enable;
    reg parity_odd_n_even;
    reg [3:0] bit_count;
    reg [3:0] stop_count;
    reg rx_manual;
    reg rx_manual_n_auto;

    wire rx;
    wire rx_auto;
    wire strobe_done;
    wire [15:0] data;
    wire parity_error;
    wire stop_error;
    wire other_error;

    integer i;

    assign rx = rx_manual_n_auto ? rx_manual : rx_auto;

    signal_history rx_history(
        .clk(clk),
        .signal(rx)
    );

    signal_history strobe_start_history(
        .clk(clk),
        .signal(uart_rx.strobe_start)
    );

    signal_history strobe_sample_history(
        .clk(clk),
        .signal(uart_rx.strobe_sample)
    );

    signal_history strobe_transition_history(
        .clk(clk),
        .signal(uart_rx.strobe_transition)
    );

    signal_history strobe_done_history(
        .clk(clk),
        .signal(strobe_done)
    );

    signal_history #(.WIDTH(16)) data_history(
        .clk(clk),
        .signal(data)
    );

    signal_history parity_error_history(
        .clk(clk),
        .signal(parity_error)
    );

    signal_history stop_error_history(
        .clk(clk),
        .signal(stop_error)
    );

    signal_history other_error_history(
        .clk(clk),
        .signal(other_error)
    );

    uart_tester uart_tester(
        .clk(clk),
        .rst(rst),
        .tx(rx_auto),
        .rx(1'b1)
    );

    uart_rx uart_rx(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .div(div),
        .parity_enable(parity_enable),
        .parity_odd_n_even(parity_odd_n_even),
        .bit_count(bit_count),
        .stop_count(stop_count),

        .rx(rx),

        .strobe_done(strobe_done),
        .data(data),
        .parity_error(parity_error),
        .stop_error(stop_error),
        .other_error(other_error)
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
        enable = 'hx;
        div = 'hx;
        parity_enable = 'hx;
        parity_odd_n_even = 'hx;
        bit_count = 'hx;
        stop_count = 'hx;
        rx_manual = 'hx;
        rx_manual_n_auto = 0;
    end

    task reset_history;
        integer i;
        begin
            rx_history.reset();
            strobe_start_history.reset();
            strobe_sample_history.reset();
            strobe_transition_history.reset();
            strobe_done_history.reset();
            data_history.reset();
            parity_error_history.reset();
            stop_error_history.reset();
            other_error_history.reset();
        end
    endtask

    task uart_send_raw;
        input integer period;
        input integer value;
        input integer value_bits;

        begin
            repeat (value_bits) begin
                rx_manual = value[0];
                value = value >> 1;
                #(period);
            end
        end
    endtask

    task random_settings;
        input integer index;
        output reg parity_enable;
        output reg parity_odd_n_even;
        output reg [3:0] bit_count;
        output reg [3:0] stop_count;
        output integer transfers;
        output integer period;
        begin
            if (index == 0) begin
                // Min
                parity_enable = 0;
                parity_odd_n_even = 0;
                bit_count = 1;
                stop_count = 1;
                transfers = 1;
                period = 20;
            end else if (index == 1) begin
                // Max
                parity_enable = 1;
                parity_odd_n_even = 1;
                bit_count = 15;
                stop_count = 15;
                transfers = 1;
                period = 400;
            end else if (index == 2) begin
                // Typical
                parity_enable = 0;
                parity_odd_n_even = 0;
                bit_count = 8;
                stop_count = 1;
                transfers = 1;
                period = 100;
            end else begin
                // Random
                parity_enable = {$random} % 2;      // 0 to 1
                parity_odd_n_even = {$random} % 2;  // 0 to 1
                bit_count = ({$random} % 14) + 1;   // 1 to 15
                stop_count = ({$random} % 14) + 1;  // 1 to 15
                transfers = ({$random} % 10) + 1;   // >= 1
                period = ({$random} % 400) + 400;   // >= 400
            end
        end
    endtask

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

    task normal_operation_testcase;
        integer period;
        integer value;
        integer raw_value;
        integer transfers;
        integer value_history[0:`HISTORY_DEPTH];
        integer i;
        integer bit_mask;
        integer done_cycle;
        integer index;

        begin
            rx_manual_n_auto = 0;
            reset(20);

            index = 0;
            /* Uncomment for debugging
            $display("index               parity_enable       parity_odd_n_even   bit_count           stop_count          transfers           period");
             */
            for (index = 0; index < 20; index = index + 1) begin

                @(negedge clk);
                random_settings(index, parity_enable, parity_odd_n_even, bit_count, stop_count, transfers, period);
                /* Uncomment for debugging
                $display("%5d%20d%20d%20d%20d%20d%20d", index, parity_enable, parity_odd_n_even, bit_count, stop_count, transfers, period);
                 */

                uart_tester.set_period(period);
                uart_tester.set_parity(parity_enable, parity_odd_n_even);
                uart_tester.set_data_bits(bit_count);
                uart_tester.set_stop_bits(stop_count);

                div = period / 10;
                enable = 0;
                reset_history();

                @(negedge clk);
                enable = 1;

                bit_mask = (1 << bit_count) - 1;
                for (i = 0; i < transfers; i = i + 1) begin
                    value = $random & bit_mask;
                    uart_tester.send(value);
                    `util_assert(i < `HISTORY_DEPTH);
                    if (i < `HISTORY_DEPTH) begin
                        value_history[i] = value;
                    end
                end

                #30

                `util_assert_equal(transfers * 2, strobe_done_history.events);
                `util_assert_equal(1, strobe_done_history.get_value(0));
                for (i = 0; i < transfers; i = i + 1) begin
                    done_cycle = strobe_done_history.get_cycle(i * 2);
                    `util_assert_equal(value_history[i], data_history.value_at_cycle(done_cycle));
                    `util_assert_equal(0, parity_error_history.value_at_cycle(done_cycle));
                    `util_assert_equal(0, stop_error_history.value_at_cycle(done_cycle));
                    `util_assert_equal(0, other_error_history.value_at_cycle(done_cycle));
                end
            end
        end
    endtask

    task timing_testcase;
        integer period;
        integer i;
        integer start_cycle;
        integer expected_cycle;

        integer rx_falling_edge_cycle;
        integer first_sample_cycle;
        integer first_transition_cycle;
        integer done_cycle;
        integer strobe_start_count;
        integer strobe_sample_count;
        integer strobe_transition_count;
        integer strobe_done_count;
        begin
            rx_manual_n_auto = 1;
            rx_manual = 1;
            enable = 0;
            period = 100;
            reset(20);

            @(negedge clk);
            div = 10;
            parity_enable = 0;
            parity_odd_n_even = 0;
            bit_count = 2;
            stop_count = 2;
            enable = 1;
            reset_history();

            // Falling edge - @ +0, negedge cycle 0
            rx_manual = 0;
            #10
            rx_manual = 'hx;

            // Start bit sample @ +50, negedge cycle 5
            #40
            rx_manual = 0;
            #10
            rx_manual = 'hx;

            // Data 0 @ +150, negedge cycle 15
            #90
            rx_manual = 1;
            #10
            rx_manual = 'hx;

            // Data 1 @ +250, negedge cycle 25
            #90
            rx_manual = 0;
            #10
            rx_manual = 'hx;

            // Stop 1 @ +350, negedge cycle 35
            #90
            rx_manual = 1;
            #10
            rx_manual = 'hx;

            // Stop 2 @ +450, negedge cycle 45
            #90
            rx_manual = 1;
            #10
            rx_manual = 'hx;

            #100

            // Compute values used in later assertions
            rx_falling_edge_cycle = rx_history.get_cycle(0);
            first_sample_cycle = rx_falling_edge_cycle + div / 2;
            first_transition_cycle = rx_falling_edge_cycle + div;
            done_cycle = first_sample_cycle + (bit_count + stop_count) * div + 1;
            strobe_start_count = 1;
            strobe_sample_count = 1 + bit_count + stop_count;
            strobe_transition_count = bit_count + stop_count;
            strobe_done_count = 1;
            // Sanity checks for test signals
            `util_assert_equal(0, rx_history.get_value(0));

            // Check that the correct number of events occurred
            `util_assert_equal(strobe_start_count * 2, strobe_start_history.events);
            `util_assert_equal(strobe_sample_count * 2, strobe_sample_history.events);
            `util_assert_equal(strobe_transition_count * 2, strobe_transition_history.events);
            `util_assert_equal(strobe_done_count * 2, strobe_done_history.events);

            // Check that all strobes are asserted for a single cycle
            for (i = 0; i < strobe_start_count; i = i + 1) begin
                `util_assert_equal(1, strobe_start_history.get_value(i * 2 + 0));
                `util_assert_equal(0, strobe_start_history.get_value(i * 2 + 1));
                `util_assert_equal(strobe_start_history.get_cycle(i * 2 + 0) + 1,
                                   strobe_start_history.get_cycle(i * 2 + 1));
            end
            for (i = 0; i < strobe_sample_count; i = i + 1) begin
                `util_assert_equal(1, strobe_sample_history.get_value(i * 2 + 0));
                `util_assert_equal(0, strobe_sample_history.get_value(i * 2 + 1));
                `util_assert_equal(strobe_sample_history.get_cycle(i * 2 + 0) + 1,
                                   strobe_sample_history.get_cycle(i * 2 + 1));
            end
            for (i = 0; i < strobe_transition_count; i = i + 1) begin
                `util_assert_equal(1, strobe_transition_history.get_value(i * 2 + 0));
                `util_assert_equal(0, strobe_transition_history.get_value(i * 2 + 1));
                `util_assert_equal(strobe_transition_history.get_cycle(i * 2 + 0) + 1,
                                   strobe_transition_history.get_cycle(i * 2 + 1));
            end
            for (i = 0; i < strobe_done_count; i = i + 1) begin
                `util_assert_equal(1, strobe_done_history.get_value(i * 2 + 0));
                `util_assert_equal(0, strobe_done_history.get_value(i * 2 + 1));
                `util_assert_equal(strobe_done_history.get_cycle(i * 2 + 0) + 1,
                                   strobe_done_history.get_cycle(i * 2 + 1));
            end

            // Check that strobes are asserted at the correct time
            `util_assert_equal(1, strobe_start_history.value_at_cycle(rx_falling_edge_cycle));
            for (i = 0; i < strobe_sample_count; i = i + 1) begin
                `util_assert_equal(1, strobe_sample_history.value_at_cycle(first_sample_cycle + div * i));
            end
            for (i = 0; i < strobe_transition_count; i = i + 1) begin
                `util_assert_equal(1, strobe_transition_history.value_at_cycle(first_transition_cycle + div * i));
            end
            `util_assert_equal(1, strobe_done_history.value_at_cycle(done_cycle));

            // Check that data was the correct value on the data strobe
            `util_assert_equal(1, data_history.value_at_cycle(done_cycle));
            `util_assert_equal(0, parity_error_history.value_at_cycle(done_cycle));
            `util_assert_equal(0, stop_error_history.value_at_cycle(done_cycle));
            `util_assert_equal(0, other_error_history.value_at_cycle(done_cycle));
        end
    endtask

    task errors_testcase;
        integer period;
        integer value;
        integer done_cycle;
        begin
            rx_manual_n_auto = 0;
            enable = 1;


            // Test an invalid start - a 1 cycle start
            reset(20);
            @(negedge clk);
            rx_manual = 1;
            rx_manual_n_auto = 1;
            period = 100;
            parity_enable = 1;
            parity_odd_n_even = i & 1;
            bit_count = 8;
            stop_count = 1;
            div = period / 10;
            reset_history();

            @(negedge clk);
            rx_manual = 0;

            @(negedge clk);
            rx_manual = 1;

            #1000

            `util_assert_equal(2, strobe_done_history.events);
            `util_assert_equal(1, strobe_done_history.get_value(0));
            done_cycle = strobe_done_history.get_cycle(0);
            `util_assert_equal(0, parity_error_history.value_at_cycle(done_cycle));
            `util_assert_equal(0, stop_error_history.value_at_cycle(done_cycle));
            `util_assert_equal(1, other_error_history.value_at_cycle(done_cycle));


            // Test even and odd parity errors
            rx_manual_n_auto = 0;
            reset(20);
            for (i = 0; i < 10; i = i + 1) begin

                @(negedge clk);
                period = 100;
                parity_enable = 1;
                parity_odd_n_even = i & 1;
                bit_count = 8;
                stop_count = 1;
                div = period / 10;
                reset_history();

                uart_tester.set_period(100);
                uart_tester.set_parity(parity_enable, !parity_odd_n_even);
                uart_tester.set_data_bits(bit_count);
                uart_tester.set_stop_bits(stop_count);

                value = {$random} % 256;
                uart_tester.send(value);

                #30

                `util_assert_equal(2, strobe_done_history.events);
                `util_assert_equal(1, strobe_done_history.get_value(0));
                done_cycle = strobe_done_history.get_cycle(0);
                `util_assert_equal(value, data_history.value_at_cycle(done_cycle));
                `util_assert_equal(1, parity_error_history.value_at_cycle(done_cycle));
                `util_assert_equal(0, stop_error_history.value_at_cycle(done_cycle));
                `util_assert_equal(0, other_error_history.value_at_cycle(done_cycle));
            end

            // Test incorrect number of stop conditions
            rx_manual_n_auto = 0;
            reset(20);
            for (i = 1; i < 10; i = i + 1) begin

                @(negedge clk);
                period = 100;
                parity_enable = 0;
                parity_odd_n_even = 0;
                bit_count = 8;
                stop_count = 1 + i;
                div = period / 10;
                reset_history();

                uart_tester.set_period(100);
                uart_tester.set_parity(parity_enable, parity_odd_n_even);
                uart_tester.set_data_bits(bit_count);
                uart_tester.set_stop_bits(i);

                value = {$random} % 256;
                uart_tester.send(value);
                uart_tester.send({$random} % 256);

                `util_assert(strobe_done_history.events >= 2);
                `util_assert_equal(1, strobe_done_history.get_value(0));
                done_cycle = strobe_done_history.get_cycle(0);
                `util_assert_equal(value, data_history.value_at_cycle(done_cycle));
                `util_assert_equal(0, parity_error_history.value_at_cycle(done_cycle));
                `util_assert_equal(1, stop_error_history.value_at_cycle(done_cycle));
                `util_assert_equal(0, other_error_history.value_at_cycle(done_cycle));

                // Give a whole transfer time to let any previous transfers finish
                #(period * (1 + bit_count + stop_count));
            end
        end
    endtask

    initial begin
        normal_operation_testcase();
        timing_testcase();
        errors_testcase();

        -> terminate_sim;
    end

endmodule
