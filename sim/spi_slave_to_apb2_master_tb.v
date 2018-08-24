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

module spi_slave_to_apb2_master_tb;
    parameter ADDR_BYTES = 2;
    reg clk, rst;
    reg spi_start, spi_next, spi_stop;
    reg [7:0] from_spi;
    wire [7:0] to_spi;
    wire [ADDR_BYTES * 8 - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [7:0] PWDATA;
    wire [7:0] PRDATA;

    apb2_master_tester #(.ADDR_BITS(ADDR_BYTES * 8), .DATA_BITS(8)) apb2_master_tester(
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    spi_slave_to_apb2_master #(.ADDR_BYTES(ADDR_BYTES)) spi_slave_to_apb2_master(
        .clk(clk),
        .rst(rst),
        .spi_start(spi_start),
        .spi_next(spi_next),
        .spi_stop(spi_stop),
        .from_spi(from_spi),
        .to_spi(to_spi),

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
        spi_start = 0;
        spi_next = 0;
        spi_stop = 0;
        from_spi = 'dx;
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

    task transfer_start;
        begin
            @(negedge clk);
            spi_start = 1;
            @(negedge clk);
            spi_start = 0;
        end
    endtask

    task transfer_next;
        input reg [31:0] from_spi_to_dut;
        output reg [31:0] to_spi_from_dut;
        begin
            // Allow 4 cycles for each spi transfer
            spi_next = 1;
            from_spi = from_spi_to_dut;
            @(posedge clk);
            to_spi_from_dut = to_spi;
            @(negedge clk);
            spi_next = 0;
            from_spi = 'dx;
            @(negedge clk);
            @(negedge clk);
            @(negedge clk);
        end
    endtask

    task transfer_finish;
        begin
            @(negedge clk);
            spi_stop = 1;
            @(negedge clk);
            spi_stop = 0;
        end
    endtask

    task normal_operation_testcase;
        integer i, j;
        reg [ADDR_BYTES * 8 - 1:0] transfer_addr;
        reg [7:0] from_spi_to_dut;
        reg [31:0] to_spi_from_dut;
        reg [3:0] transfer_cycles;
        reg write_n_read;
        integer expected_memory_write_count;
        reg [31:0] expected_to_spi_from_dut;
        begin

            reset(20);
            expected_memory_write_count = 0;

            for (i = 0; i < 20; i = i + 1) begin

                transfer_addr = $random;
                write_n_read = $random;
                transfer_cycles = $random;

                apb2_master_tester.mem_reset();
                    if (!write_n_read) begin
                    for (j = 0; j < transfer_cycles; j = j + 1) begin
                        apb2_master_tester.mem_set(transfer_addr + j, $random);
                    end
                end

                transfer_start();
                transfer_next((transfer_addr >> 0) & 'hFF, to_spi_from_dut);
                expected_to_spi_from_dut = 0;
                `util_assert_equal(expected_to_spi_from_dut, to_spi_from_dut);

                transfer_next((transfer_addr >> 8) & 'hFF, to_spi_from_dut);
                expected_to_spi_from_dut = 0;
                `util_assert_equal(expected_to_spi_from_dut, to_spi_from_dut);

                transfer_next(write_n_read, to_spi_from_dut);
                apb2_master_tester.mem_get(transfer_addr, expected_to_spi_from_dut);
                `util_assert_equal(expected_to_spi_from_dut, to_spi_from_dut);

                for (j = write_n_read ? 0 : 1; j < transfer_cycles; j = j + 1) begin
                    if (write_n_read) begin
                        from_spi_to_dut = $random;

                        transfer_next(from_spi_to_dut, to_spi_from_dut);
                        expected_memory_write_count = expected_memory_write_count + 1;
                        `util_assert_equal(0, to_spi_from_dut);
                        `util_assert_equal(apb2_master_tester.last_write, from_spi_to_dut);
                        `util_assert_display(apb2_master_tester.last_addr === transfer_addr + j, ("Data written to wrong address expected 0x%h got 0x%h", transfer_addr + j, apb2_master_tester.last_addr));
                        `util_assert_equal(expected_memory_write_count, apb2_master_tester.write_count);

                    end else begin
                        from_spi_to_dut = $random;
                        apb2_master_tester.mem_get(transfer_addr + j, expected_to_spi_from_dut);
                        transfer_next(from_spi_to_dut, to_spi_from_dut);
                        `util_assert_equal(expected_to_spi_from_dut, to_spi_from_dut);
                    end
                end
                transfer_finish();
            end
        end
    endtask


    initial begin
        normal_operation_testcase();
        -> terminate_sim;
    end

endmodule
