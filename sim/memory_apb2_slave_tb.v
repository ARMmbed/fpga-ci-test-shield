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

module memory_apb2_slave_tb;
    parameter ADDR_BITS = 6;
    parameter DATA_BITS = 8;
    parameter RW_SIZE = 8;
    parameter RO_SIZE = 8;
    reg clk, rst;
    wire [RW_SIZE * DATA_BITS - 1:0] mem_rw_values;
    reg [RO_SIZE * DATA_BITS - 1:0] mem_ro_values;

    integer i;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    memory_apb2_slave #(.RW_SIZE(RW_SIZE), .RO_SIZE(RO_SIZE), .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) memory_apb2_slave(
        .clk(clk),
        .rst(rst),
        .mem_rw_values(mem_rw_values),
        .mem_ro_values(mem_ro_values),
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
        for (i = 0; i < RO_SIZE; i = i + 1) begin
            mem_ro_values[i * 8+:8] = $random;
        end
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
        reg [DATA_BITS - 1:0] expected_rw_contents[0:RW_SIZE - 1];
        reg [DATA_BITS - 1:0] expected;
        reg [DATA_BITS - 1:0] from_mem;
        begin
            reset(20);

            for (i = 0; i < RW_SIZE; i = i + 1) begin
                // Fill in initial contents
                expected_rw_contents[i] = $random;
                apb2_slave_tester.write(i, expected_rw_contents[i]);
            end

            for (i = 0; i < RW_SIZE + RO_SIZE + 8; i = i + 1) begin

                apb2_slave_tester.read(i, from_mem);
                if (i < RW_SIZE)
                    expected = expected_rw_contents[i];
                else if (i < RW_SIZE + RO_SIZE)
                    expected = mem_ro_values[(i - RW_SIZE) * DATA_BITS+:DATA_BITS];
                else
                    expected = 0;
                `util_assert_display(from_mem === expected, ("Wrong value at addr %h is 0x%x expected 0x%x", i, from_mem, expected));
            end

        end
    endtask

    initial begin
        normal_operation_testcase();
        -> terminate_sim;
    end

endmodule
