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

module spi_slave_tb;
    parameter MAIN_CLOCK = 10;
    reg clk;
    reg rst;
    wire sout;
    reg sin;
    reg sclk;
    reg scs;
    reg [31:0] dout;
    reg [1:0] mode;
    reg bit_order;
    reg [5:0] sym_size;
    reg [5:0] msb_idx;
    wire [31:0] din;
    wire start, next, stop;

    reg [31:0] expected_din;

    spi_slave #(.DATA_BUS_WIDTH(32)) spi_slave(
        .clk(clk),
        .rst(rst),
        .sout(sout),
        .sin(sin),
        .sclk(sclk),
        .scs(scs),
        .mode(mode),
        .bit_order(bit_order),
        .sym_size(sym_size),
        .dout(dout),
        .din(din),
        .start(start),
        .next(next),
        .stop(stop)
    );

    initial  begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always
        #(MAIN_CLOCK/2) clk = !clk;

    always @(posedge clk) begin

        // Check that the data is valid
        if (next) begin
            `util_assert_equal(expected_din, din);
        end
    end

    initial begin
        // Default: 8 bit symbol / Mode 0 / MSB first / Full Duplex
        clk = 0;
        sin = 0;
        sclk = 0;
        scs = 0;
        dout = 8'b0;
        mode = 0;
        bit_order = 0;
        sym_size = 8;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_default(8'hAA, 8'h42, 1);
        spi_transfer_default(8'hFF, 8'hFF, 1);
        spi_transfer_default(8'h00, 8'h00, 1);
        spi_transfer_default(8'h12, 8'hAA, 0);
        scs = 0;
        sclk = 0;
        #200

        // Mode 1 (SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE)
        clk = 0;
        sin = 0;
        sclk = 0;
        scs = 0;
        dout = 8'b0;
        mode = 1;
        bit_order = 0;
        sym_size = 8;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_mode_1(8'hAA, 8'h42, 1);
        spi_transfer_mode_1(8'hFF, 8'hFF, 1);
        spi_transfer_mode_1(8'h00, 8'h00, 1);
        spi_transfer_mode_1(8'h12, 8'hAA, 0);
        scs = 0;
        #200

        // Mode 2 (SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE)
        clk = 0;
        sin = 0;
        sclk = 1;
        scs = 0;
        dout = 8'b0;
        mode = 2;
        bit_order = 0;
        sym_size = 8;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_mode_2(8'hAA, 8'h42, 1);
        spi_transfer_mode_2(8'hFF, 8'hFF, 1);
        spi_transfer_mode_2(8'h00, 8'h00, 1);
        spi_transfer_mode_2(8'h12, 8'hAA, 0);
        scs = 0;
        #200

        // Mode 3 (SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE)
        clk = 0;
        sin = 0;
        sclk = 1;
        scs = 0;
        dout = 8'b0;
        mode = 3;
        bit_order = 0;
        sym_size = 8;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_mode_3(8'hAA, 8'h42, 1);
        spi_transfer_mode_3(8'hFF, 8'hFF, 1);
        spi_transfer_mode_3(8'h00, 8'h00, 1);
        spi_transfer_mode_3(8'h12, 8'hAA, 0);
        scs = 0;
        #200

        // Bit ordering: LSB first
        clk = 0;
        sin = 0;
        sclk = 0;
        scs = 0;
        dout = 8'b0;
        mode = 0;
        bit_order = 1;
        sym_size = 8;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_lsb_first(8'hAA, 8'h42, 1);
        spi_transfer_lsb_first(8'hFF, 8'hFF, 1);
        spi_transfer_lsb_first(8'h00, 8'h00, 1);
        spi_transfer_lsb_first(8'h12, 8'hAA, 0);
        scs = 0;
        sclk = 0;
        #200

        // Symbol size: 16 bits
        clk = 0;
        sin = 0;
        sclk = 0;
        scs = 0;
        dout = 8'b0;
        mode = 0;
        bit_order = 0;
        sym_size = 16;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_default(16'hAAAA, 16'h4242, 1);
        spi_transfer_default(16'hFFFF, 16'hFFFF, 1);
        spi_transfer_default(16'h0000, 16'h0000, 1);
        spi_transfer_default(16'h1212, 16'hAAAA, 0);
        scs = 0;
        sclk = 0;
        #200

        // Symbol size: 32 bits
        clk = 0;
        sin = 0;
        sclk = 0;
        scs = 0;
        dout = 8'b0;
        mode = 0;
        bit_order = 0;
        sym_size = 32;
        msb_idx = sym_size - 1;
        rst = 1;
        #20
        @(negedge clk);
        rst = 0;
        scs = 1;
        spi_transfer_default(32'hAAAAAAAA, 32'h42424242, 1);
        spi_transfer_default(32'hFFFFFFFF, 32'hFFFFFFFF, 1);
        spi_transfer_default(32'h00000000, 32'h00000000, 1);
        spi_transfer_default(32'h12121212, 32'hAAAAAAAA, 0);
        scs = 0;
        sclk = 0;
        #200

        $finish;
    end

    task spi_transfer_default;
        input [31:0] to_dut;
        input [31:0] expected_dout;
        input continue;
        integer i;
        integer sent_by_dut;

        begin
            dout = expected_dout;

            if (scs !== 1) begin
                scs = 1;
                #50
                sent_by_dut = 0;
            end else begin
                sent_by_dut = 0;
            end

            for (i = 0; i < sym_size; i = i + 1) begin
                #50
                sclk = 0;
                sin = to_dut[msb_idx-i];
                #50
                expected_din = to_dut;
                sclk = 1;
                sent_by_dut = (sent_by_dut << 1) | sout;
            end
            `util_assert_equal(expected_dout, sent_by_dut);
        end
    endtask

    task spi_transfer_mode_1;
        input [31:0] to_dut;
        input [31:0] expected_dout;
        input continue;
        integer i;
        integer sent_by_dut;

        begin
            dout = expected_dout;

            if (scs !== 1) begin
                scs = 1;
                #50
                sent_by_dut = 0;
            end else begin
                sent_by_dut = 0;
            end

            sclk = 0;
            for (i = 0; i < sym_size; i = i + 1) begin
                #50
                sclk = 1;
                sin = to_dut[msb_idx-i];
                #50
                expected_din = to_dut;
                sclk = 0;
                sent_by_dut = (sent_by_dut << 1) | sout;
            end
            `util_assert_equal(expected_dout, sent_by_dut);
        end
    endtask

    task spi_transfer_mode_2;
        input [31:0] to_dut;
        input [31:0] expected_dout;
        input continue;
        integer i;
        integer sent_by_dut;

        begin
            dout = expected_dout;

            if (scs !== 1) begin
                scs = 1;
                #50
                sent_by_dut = 0;
            end else begin
                sent_by_dut = 0;
            end

            for (i = 0; i < sym_size; i = i + 1) begin
                #50
                sclk = 1;
                sin = to_dut[msb_idx-i];
                #50
                expected_din = to_dut;
                sclk = 0;
                sent_by_dut = (sent_by_dut << 1) | sout;
            end
            `util_assert_equal(expected_dout, sent_by_dut);
        end
    endtask

    task spi_transfer_mode_3;
        input [31:0] to_dut;
        input [31:0] expected_dout;
        input continue;
        integer i;
        integer sent_by_dut;

        begin
            dout = expected_dout;

            if (scs !== 1) begin
                scs = 1;
                #50
                sent_by_dut = 0;
            end else begin
                sent_by_dut = 0;
            end

            for (i = 0; i < sym_size; i = i + 1) begin
                #50
                sclk = 0;
                sin = to_dut[msb_idx-i];
                #50
                expected_din = to_dut;
                sclk = 1;
                sent_by_dut = (sent_by_dut << 1) | sout;
            end
            `util_assert_equal(expected_dout, sent_by_dut);
        end
    endtask

    task spi_transfer_lsb_first;
        input [31:0] to_dut;
        input [31:0] expected_dout;
        input continue;
        integer i;
        integer sent_by_dut;

        begin
            dout = expected_dout;

            if (scs !== 1) begin
                scs = 1;
                #50
                sent_by_dut = 0;
            end else begin
                sent_by_dut = 0;
            end

            for (i = 0; i < sym_size; i = i + 1) begin
                #50
                sclk = 0;
                sin = to_dut[i];
                #50
                expected_din = to_dut;
                sclk = 1;
                sent_by_dut = (sout  <<  i) | sent_by_dut;
            end
            `util_assert_equal(expected_dout, sent_by_dut);
        end
    endtask

endmodule
