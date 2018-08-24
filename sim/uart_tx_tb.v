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

module uart_tx_tb;
    reg clk, rst;
    reg enable;
    reg [15:0] div;
    reg parity_enable;
    reg parity_odd_n_even;
    reg [3:0] bit_count;
    reg [3:0] stop_count;
    reg [15:0] data;
    reg send;

    wire tx;
    wire ready;
    wire strobe_started;

    signal_history send_history(
        .clk(clk),
        .signal(send)
    );

    signal_history tx_history(
        .clk(clk),
        .signal(tx)
    );

    signal_history ready_history(
        .clk(clk),
        .signal(ready)
    );

    signal_history strobe_started_history(
        .clk(clk),
        .signal(strobe_started)
    );

    uart_tester uart_tester(
        .clk(clk),
        .rst(rst),
        .tx(),
        .rx(tx)
    );

    uart_tx uart_tx(
        .clk(clk),
        .rst(rst),
        .div(div),
        .parity_enable(parity_enable),
        .parity_odd_n_even(parity_odd_n_even),
        .bit_count(bit_count),
        .stop_count(stop_count),
        .data(data),
        .send(send),

        .tx(tx),
        .ready(ready),
        .strobe_started(strobe_started)
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
        div = 'hx;
        parity_enable = 'hx;
        parity_odd_n_even = 'hx;
        bit_count = 'hx;
        stop_count = 'hx;
        data = 'hx;
        send = 'hx;
    end

    task reset_history;
        integer i;
        begin
            send_history.reset();
            tx_history.reset();
            ready_history.reset();
            strobe_started_history.reset();
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
                reset_history();
                uart_tester.receive_start();

                @(negedge clk);
                bit_mask = (1 << bit_count) - 1;
                for (i = 0; i < transfers; i = i + 1) begin
                    value = $random & bit_mask;
                    `util_assert(i < `HISTORY_DEPTH);
                    if (i < `HISTORY_DEPTH) begin
                        value_history[i] = value;
                    end
                    data = value;
                    send = 1;

                    @(posedge strobe_started);
                    @(negedge clk);
                end

                send = 0;

                wait (ready);
                #100;

                uart_tester.receive_stop();

                // Assert that ready was low during the burst
                `util_assert_equal(2, ready_history.events);
                `util_assert_equal(0, ready_history.get_value(0));
                `util_assert_equal(1, ready_history.get_value(1));

                // Check the values are right
                `util_assert_equal(transfers * 2, strobe_started_history.events);
                `util_assert_equal(1, strobe_started_history.get_value(0));
                `util_assert_equal(transfers, uart_tester.receive_count);
                for (i = 0; i < transfers; i = i + 1) begin
                    `util_assert_equal(1, uart_tester.receive_value_valid(i));
                    `util_assert_equal(value_history[i], uart_tester.receive_value(i));
                end
            end
        end
    endtask

    task timing_testcase;
        integer i;
        integer start_cycle;
        integer start_cycle2;
        integer expected_cycle;
        integer div_const;
        integer clk_period;
        begin
            div_const = 5;
            clk_period = 10;
            send = 0;
            reset(20);

            /*
             * Given a one cycle test pulse:
             *
             *
             *      1        -
             * send
             *      0   ----- ------------------------------
             *
             *
             * Test that the folloing sequence occurs:
             *
             *                                    stop2
             *          idle       data[0]   stop1     idle
             *      1   ------     -----     ---------------
             * tx
             *      0         -----     -----
             *                start     data[1]
             *
             *
             *      1   ------                         -----
             * ready
             *      0         -------------------------
             *
             *
             *      1         -
             * strobe_started
             *      0   ------ -----------------------------
             *
             */

            @(negedge clk);
            reset_history();

            #100

            @(negedge clk);
            div = div_const;
            parity_enable = 0;
            parity_odd_n_even = 0;
            bit_count = 2;
            stop_count = 2;
            data = 1;
            send = 1;

            @(negedge clk);
            div = 'hx;
            parity_enable = 'hx;
            parity_odd_n_even = 'hx;
            bit_count = 'hx;
            stop_count = 'hx;
            data = 'hx;
            send = 0;

            #1000

             // Check for the correct number of transitions
            `util_assert_equal(2, send_history.events);
            `util_assert_equal(4, tx_history.events);
            `util_assert_equal(2, ready_history.events);
            `util_assert_equal(2, strobe_started_history.events);

            // Sanity check 'send' signal and use it as a starting point
            `util_assert_equal(1, send_history.get_value(0));
            `util_assert_equal(0, send_history.get_value(1));
            `util_assert_equal(send_history.get_cycle(0) + 1, send_history.get_cycle(1));
            start_cycle = send_history.get_cycle(0);

            // Check that 'tx' timings are correct
            `util_assert_equal(0, tx_history.get_value(0));
            `util_assert_equal(1, tx_history.get_value(1));
            `util_assert_equal(0, tx_history.get_value(2));
            `util_assert_equal(1, tx_history.get_value(3));
            `util_assert_equal(start_cycle + 1 + div_const * 0, tx_history.get_cycle(0));
            `util_assert_equal(start_cycle + 1 + div_const * 1, tx_history.get_cycle(1));
            `util_assert_equal(start_cycle + 1 + div_const * 2, tx_history.get_cycle(2));
            `util_assert_equal(start_cycle + 1 + div_const * 3, tx_history.get_cycle(3));

            // Check that 'ready' timings are correct
            `util_assert_equal(0, ready_history.get_value(0));
            `util_assert_equal(1, ready_history.get_value(1));
            `util_assert_equal(start_cycle + 1 + div_const * 0, ready_history.get_cycle(0));
            `util_assert_equal(start_cycle + 1 + div_const * 5, ready_history.get_cycle(1));

            // Check that 'strobe_started' timings are correct
            `util_assert_equal(1, strobe_started_history.get_value(0));
            `util_assert_equal(0, strobe_started_history.get_value(1));
            `util_assert_equal(start_cycle + 1 + 0, strobe_started_history.get_cycle(0));
            `util_assert_equal(start_cycle + 1 + 1, strobe_started_history.get_cycle(1));

            /*
             * Given two single cycle test pulses and different settings:
             *
             *
             *      1        -                   -
             * send
             *      0   ----- ------------------- -------------------------
             *
             *
             * Test that the folloing sequence occurs:
             *
             *
             *          idle       data[0]   stop                stop idle
             *      1   ------     -----     -----               ----------
             * tx
             *      0         -----     -----     ---------------
             *                start     data[1]   start     data[1]
             *                                         data[0]
             *
             *
             *      1   ------                                        -----
             * ready
             *      0         ----------------------------------------
             *
             *
             *      1         -                   -
             * strobe_started
             *      0   ------ ------------------- ------------------------
             *
             */

            @(negedge clk);
            reset_history();

            #100

            @(negedge clk);
            div = div_const;
            parity_enable = 0;
            parity_odd_n_even = 0;
            bit_count = 2;
            stop_count = 1;
            data = 1;
            send = 1;

            @(negedge clk);
            div = 'hx;
            parity_enable = 'hx;
            parity_odd_n_even = 'hx;
            bit_count = 'hx;
            stop_count = 'hx;
            data = 'hx;
            send = 0;

            #((div_const * 4 - 1) * clk_period);

            @(negedge clk);
            div = div_const;
            parity_enable = 0;
            parity_odd_n_even = 0;
            bit_count = 2;
            stop_count = 1;
            data = 0;
            send = 1;

            @(negedge clk);
            div = 'hx;
            parity_enable = 'hx;
            parity_odd_n_even = 'hx;
            bit_count = 'hx;
            stop_count = 'hx;
            data = 'hx;
            send = 0;

            #1000

             // Check for the correct number of transitions
            `util_assert_equal(4, send_history.events);
            `util_assert_equal(6, tx_history.events);
            `util_assert_equal(2, ready_history.events);
            `util_assert_equal(4, strobe_started_history.events);

            // Sanity check 'send' signals and use them as a starting point
            `util_assert_equal(1, send_history.get_value(0));
            `util_assert_equal(0, send_history.get_value(1));
            `util_assert_equal(send_history.get_cycle(0) + 1, send_history.get_cycle(1));
            start_cycle = send_history.get_cycle(0);
            `util_assert_equal(1, send_history.get_value(2));
            `util_assert_equal(0, send_history.get_value(3));
            `util_assert_equal(send_history.get_cycle(2) + 1, send_history.get_cycle(3));
            start_cycle2 = send_history.get_cycle(2);
            `util_assert_equal(start_cycle + div_const * 4, start_cycle2);

            // Check that the first 'tx' timings are correct
            `util_assert_equal(0, tx_history.get_value(0));
            `util_assert_equal(1, tx_history.get_value(1));
            `util_assert_equal(start_cycle + 1 + div_const * 0, tx_history.get_cycle(0));
            `util_assert_equal(start_cycle + 1 + div_const * 1, tx_history.get_cycle(1));
            // Check that the second 'tx' timings are correct
            `util_assert_equal(0, tx_history.get_value(2));
            `util_assert_equal(1, tx_history.get_value(3));
            `util_assert_equal(start_cycle + 1 + div_const * 2, tx_history.get_cycle(2));
            `util_assert_equal(start_cycle + 1 + div_const * 3, tx_history.get_cycle(3));

            // Check that 'ready' timings are correct
            `util_assert_equal(0, ready_history.get_value(0));
            `util_assert_equal(1, ready_history.get_value(1));
            `util_assert_equal(start_cycle + 1 + div_const * 0, ready_history.get_cycle(0));
            `util_assert_equal(start_cycle2 + 1 + div_const * 4, ready_history.get_cycle(1));

            // Check that the first 'strobe_started' timings are correct
            `util_assert_equal(1, strobe_started_history.get_value(0));
            `util_assert_equal(0, strobe_started_history.get_value(1));
            `util_assert_equal(start_cycle + 1 + 0, strobe_started_history.get_cycle(0));
            `util_assert_equal(start_cycle + 1 + 1, strobe_started_history.get_cycle(1));
            // Check that the second 'strobe_started' timings are correct
            `util_assert_equal(1, strobe_started_history.get_value(2));
            `util_assert_equal(0, strobe_started_history.get_value(3));
            `util_assert_equal(start_cycle2 + 1 + 0, strobe_started_history.get_cycle(2));
            `util_assert_equal(start_cycle2 + 1 + 1, strobe_started_history.get_cycle(3));

        end
    endtask

    initial begin
        normal_operation_testcase();
        timing_testcase();

        -> terminate_sim;
    end

endmodule
