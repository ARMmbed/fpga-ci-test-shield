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

module spi_sequence_detector_tb;
    reg clk, rst;
    wire sout, sin, sclk, match;
    integer i;

    spi_slave_tester spi(
        .clk(clk),
        .rst(rst),
        .sout(sout),
        .sin(sin),
        .sclk(sclk)
    );

    signal_history sclk_history(
        .clk(clk),
        .signal(sclk)
    );

    signal_history match_history(
        .clk(clk),
        .signal(match)
    );

    spi_sequence_detector spi_sequence_detector(
        .clk(clk),
        .rst(rst),
        .sin(sin),
        .sclk(sclk),
        .match(match)
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

    task normal_operation_testcase;
        integer bytes_to_send;
        begin
            bytes_to_send = 20;
            spi.period = 100;
            reset(20);

            sclk_history.reset();
            match_history.reset();

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            // Send a valid key
            spi.send('h92);
            spi.send('h9d);
            spi.send('h9a);
            spi.send('h9b);
            spi.send('h29);
            spi.send('h35);
            spi.send('ha2);
            spi.send('h65);

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            #100

            // Assert that there are the exact number of events that we expect
            `util_assert_equal((20 + 8 + 20) * 16, sclk_history.events);
            `util_assert_equal(2, match_history.events);

            // Check that match is asserted in the same cycle sclk goes low
            `util_assert_equal(1, match_history.get_value(0));
            `util_assert_equal(sclk_history.get_time((20 + 8) * 16 - 1), match_history.get_time(0));

            // Check that chip select is de-asserted on the next clock cycle
            `util_assert_equal(0, match_history.get_value(1));
            `util_assert_equal(match_history.get_cycle(0) + 1, match_history.get_cycle(1));

        end
    endtask

    task wrong_key_testcase;
        integer bytes_to_send;
        begin
            bytes_to_send = 20;
            spi.period = 100;
            reset(20);

            sclk_history.reset();
            match_history.reset();

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            // Send an invalid valid key
            spi.send('h12);
            spi.send('h34);
            spi.send('h56);
            spi.send('h78);
            spi.send('h90 + 1);
            spi.send('h12);
            spi.send('h34);
            spi.send('h56);

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            // Assert that match was not asserted
            `util_assert_equal(0, match_history.events);
        end
    endtask

    task reset_testcase;
        integer bytes_to_send;
        begin
            bytes_to_send = 20;
            spi.period = 100;
            reset(20);

            sclk_history.reset();
            match_history.reset();

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            // Send an invalid valid key
            spi.send('h12);
            spi.send('h34);
            spi.send('h56);
            spi.send('h78);
            @(negedge clk);
            rst = 1;
            spi.send('h90);
            @(negedge clk);
            rst = 0;
            spi.send('h12);
            spi.send('h34);
            spi.send('h56);

            // Send some dummy bytes
            repeat (bytes_to_send) begin
                spi.send($random);
            end

            // Assert that match was not asserted
            `util_assert_equal(0, match_history.events);
        end
    endtask

    initial begin
        normal_operation_testcase();
        wrong_key_testcase();
        reset_testcase();
        -> terminate_sim;
    end

endmodule
