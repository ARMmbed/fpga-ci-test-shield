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

module control_manager_tb;
    parameter SPI_COUNT = 8;
    parameter INDEX_WIDTH = 8;
    parameter ADDR_BYTES = 2;
    reg clk, rst;
    wire sclk;
    wire sin;
    wire [SPI_COUNT - 1:0] sclks, sins;
    wire [INDEX_WIDTH - 1:0] sout_index;
    wire sout_enable, sout;

    wire [ADDR_BYTES * 8 - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [7:0] PWDATA;
    wire [7:0] PRDATA;

    integer i;
    integer current_spi;
    genvar i_gen;

    for (i_gen = 0; i_gen < SPI_COUNT; i_gen = i_gen + 1) begin
        assign sclks[i_gen] = current_spi == i_gen ? sclk : 0;
        assign sins[i_gen] = current_spi == i_gen ? sin : 0;
    end

    apb2_master_tester #(.ADDR_BITS(ADDR_BYTES * 8), .DATA_BITS(8)) apb2_master_tester(
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    spi_slave_tester spi(
        .clk(clk),
        .rst(rst),
        .sout(sout),
        .sin(sin),
        .sclk(sclk)
    );

    control_manager #(.SPI_COUNT(8), .ADDR_BYTES(ADDR_BYTES)) control_manager(
        .clk(clk),
        .rst(rst),
        .sclks(sclks),
        .sins(sins),
        .sout_index(sout_index),
        .sout_enable(sout_enable),
        .sout(sout),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
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
        current_spi = 0;
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

    task send_key;
        begin
            spi.send('h92);
            spi.send('h9d);
            spi.send('h9a);
            spi.send('h9b);
            spi.send('h29);
            spi.send('h35);
            spi.send('ha2);
            spi.send('h65);
        end
    endtask


    task normal_operation_testcase;
        integer i;
        reg [7:0] expected_sout_index;
        reg [7:0] requested_cycles;
        reg [7:0] expected_output;
        reg [7:0] expected_address;
        reg [7:0] output_from_dut;
        begin

            reset(20);

            for (i = 0; i < SPI_COUNT; i = i + 1) begin
                expected_output = $random;
                expected_sout_index = $random;
                expected_address = $random;
                requested_cycles = 1;
                apb2_master_tester.mem_reset();
                apb2_master_tester.mem_set(expected_address, expected_output);

                @(negedge clk);
                current_spi = i;
                spi.period = 100;

                send_key();
                spi.send(expected_sout_index);
                spi.send(requested_cycles + 3);
                spi.send(expected_address);     // Address 0
                spi.send(0);                    // Address 1
                spi.send(0);                    // Read
                spi.transfer(7, output_from_dut);
                `util_assert_equal(expected_output, output_from_dut);
                spi.send(8);
            end
        end
    endtask


    initial begin
        normal_operation_testcase();
        -> terminate_sim;
    end

endmodule
