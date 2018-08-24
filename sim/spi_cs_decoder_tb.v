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

module spi_cs_decoder_tb;
    reg clk, rst, start;
    wire scs, sout, sin, sclk;
    wire [7:0] sindex;
    integer i;

    spi_cs_decoder spi_cs_decoder(
        .clk(clk),
        .rst(rst),
        .start(start),
        .sin(sin),
        .sclk(sclk),
        .scs(scs),
        .sindex(sindex)
    );

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
    signal_history scs_history(
        .clk(clk),
        .signal(scs)
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
        start = 0;
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

    event start_pulse;
    always begin
         @start_pulse;
         start = 1;
         @(posedge clk);
         @(negedge clk);
         start = 0;
    end

    event terminate_sim;
    initial begin
        @terminate_sim;
        #200 $finish;
    end

    task normal_operation_testcase;
        integer pin_addr;
        integer bytes_to_send;
        integer dummy_bytes;
        integer period;
        begin
            pin_addr = 'h43;
            bytes_to_send = 2;
            dummy_bytes = 5;
            spi.period = 100;
            reset(20);

            sclk_history.reset();
            scs_history.reset();

            repeat (dummy_bytes) begin
                spi.send($random);
            end

            @(negedge clk);

            -> start_pulse;
            spi.send(pin_addr);
            spi.send(bytes_to_send);

            repeat (bytes_to_send) begin
                spi.send(pin_addr);
            end

            repeat (dummy_bytes) begin
                spi.send($random);
            end

            #100

            // Assert that there are the exact number of events that we expect
            `util_assert_equal((5 + 2 + bytes_to_send + 5) * 16, sclk_history.events);
            `util_assert_equal(2, scs_history.events);

            // Check that chip select is asserted in the same cycle sclk goes low at the end of a byte
            `util_assert_equal(1, scs_history.get_value(0));
            `util_assert_equal(sclk_history.get_time((5 + 2) * 16 - 1), scs_history.get_time(0));

            // Check that chip select is de-asserted on the correct clock cycle
            `util_assert_equal(0, scs_history.get_value(1));
            `util_assert_equal(sclk_history.get_time((5 + 2 + bytes_to_send) * 16 - 1), scs_history.get_time(1));
        end
    endtask

    task reset_testcase;
        integer pin_addr;
        integer bytes_to_send;
        integer period;
        begin
            pin_addr = 'h43;
            bytes_to_send = 2;
            period = 100;
            reset(20);

            sclk_history.reset();
            scs_history.reset();

            @(negedge clk);

            -> start_pulse;
            spi.send(pin_addr + 7);

            @(negedge clk);
            rst = 1;
            @(negedge clk);
            rst = 0;

            -> start_pulse;
            spi.send(pin_addr);
            spi.send(bytes_to_send);

            repeat (bytes_to_send) begin
                spi.send(pin_addr);
            end

            #100

            // Assert that there are the exact number of events that we expect
            `util_assert_equal((3 + bytes_to_send) * 16, sclk_history.events);
            `util_assert_equal(2, scs_history.events);

            // Check that chip select is asserted in the same cycle sclk goes low at the end of a byte
            `util_assert_equal(1, scs_history.get_value(0));
            `util_assert_equal(sclk_history.get_time((3) * 16 - 1), scs_history.get_time(0));

            // Check that chip select is de-asserted on the correct clock cycle
            `util_assert_equal(0, scs_history.get_value(1));
            `util_assert_equal(sclk_history.get_time((3 + bytes_to_send) * 16 - 1), scs_history.get_time(1));
        end
    endtask

    initial begin
        normal_operation_testcase();
        reset_testcase();
        -> terminate_sim;
    end

endmodule
