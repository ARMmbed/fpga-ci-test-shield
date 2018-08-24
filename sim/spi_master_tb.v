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

module spi_master_tb;
    parameter MAIN_CLOCK = 10;
    reg clk;
    reg rst;
    wire sout;
    reg sin;
    wire sclk;
    wire scs;
    reg [31:0] dout;
    reg [1:0] mode;
    reg bit_order;
    reg [5:0] sym_size;
    reg [5:0] msb_idx;
    wire [31:0] din;
    wire next;
    wire hd_tx_rx_proc;
    reg start;
    reg [31:0] expected_din;
    reg [15:0] divisor;
    reg [7:0] delay_us;
    reg [15:0] sym_delay_ticks;
    reg [31:0] to_dut;
    reg [15:0] num_of_symbols;

    reg [31:0] sent_by_dut;
    integer bit_cnt;
    integer transmission_started = 0;
    integer tc_cnt = 0;

    spi_master #(.DATA_BUS_WIDTH(32)) spi_master(
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
        .divisor(divisor),
        .delay_us(delay_us),
        .sym_delay_ticks(sym_delay_ticks),
        .num_of_symbols(num_of_symbols),
        .hd_mode(1'b0), // Full-Duplex
        .hd_tx_rx_proc(hd_tx_rx_proc)
    );

    initial  begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always
        #(MAIN_CLOCK/2) clk = !clk;

    always @(negedge clk) begin
        // Check that the data is valid
        if (next) begin
            `util_assert_equal(dout, sent_by_dut);
            `util_assert_equal(to_dut, din);
            if (to_dut > 0)
                to_dut = to_dut - 1;
            else to_dut = 255;

            if (dout < 255)
                dout = dout + 1;
            else dout = 0;

            bit_cnt = 0;
            sent_by_dut = 32'd0;
        end
    end

    always @(posedge scs) begin
        transmission_started = 1;
    end

    always @(negedge scs) begin
        if (transmission_started == 1) begin
            transmission_started = 0;
            start = 0;
            tc_cnt = tc_cnt + 1;
            if (tc_cnt == 1) normal_operation_test_case(2'd1, 1'd0, 6'd8); // 8 bit symbol / Mode 1 / MSB first
            if (tc_cnt == 2) normal_operation_test_case(2'd2, 1'd0, 6'd8); // 8 bit symbol / Mode 2 / MSB first
            if (tc_cnt == 3) normal_operation_test_case(2'd3, 1'd0, 6'd8); // 8 bit symbol / Mode 3 / MSB first
            if (tc_cnt == 4) normal_operation_test_case(2'd0, 1'd1, 6'd8); // 8 bit symbol / Mode 0 / LSB first
            if (tc_cnt == 5) normal_operation_test_case(2'd0, 1'd0, 6'd16); // 16 bit symbol / Mode 0 / MSB first
            if (tc_cnt == 6) normal_operation_test_case(2'd0, 1'd0, 6'd32); // 32 bit symbol / Mode 0 / MSB first
            if (tc_cnt == 7) finish_bench();

        end;
    end

    always @(posedge sclk) begin
        if (start) begin
            if (mode == 0 || mode == 3) begin
                if (bit_order == 1'b0) begin
                    sent_by_dut = (sent_by_dut << 1) | sout;
                end else begin
                    sent_by_dut = (sout  <<  (bit_cnt-1)) | sent_by_dut;
                end
            end else if (mode == 1 || mode == 2) begin
                if (bit_order == 1'b0) begin
                    sin = to_dut[msb_idx - bit_cnt];
                end else begin
                    sin = to_dut[bit_cnt];
                end
                bit_cnt = bit_cnt + 1;
            end
        end
    end

    always @(negedge sclk) begin
        if (start) begin
            if (mode == 0 || mode == 3) begin
                if (bit_order == 1'b0) begin
                    sin = to_dut[msb_idx - bit_cnt];
                end else begin
                    sin = to_dut[bit_cnt];
                end
                bit_cnt = bit_cnt + 1;
            end else if (mode == 1 || mode == 2) begin
                if (bit_order == 1'b0) begin
                    sent_by_dut = (sent_by_dut << 1) | sout;
                end else begin
                    sent_by_dut = (sout  <<  (bit_cnt-1)) | sent_by_dut;
                end
            end
        end
    end

    initial begin
        tc_cnt = 0;
        normal_operation_test_case(2'd0, 1'd0, 6'd8); // default test case: 8 bit symbol / Mode 0 / MSB first
    end

    task normal_operation_test_case;
        input reg [1:0] _mode;
        input reg _bit_order;
        input reg [5:0] _sym_size;
        begin
            if (_sym_size == 8) begin
                to_dut = 8'h55;
                dout = 8'hAA;
            end else if (_sym_size == 16) begin
                to_dut = 16'h5555;
                dout = 16'hAAAA;
            end else begin
                to_dut = 32'h55555555;
                dout = 32'hAAAAAAAA;
            end

            sent_by_dut = 0;
            num_of_symbols = 300;
            sym_delay_ticks = 10;
            clk = 0;
            sym_size = _sym_size;
            msb_idx = _sym_size - 1;
            if (_bit_order == 1'b0) begin
                sin = to_dut[msb_idx];
            end else begin
                sin = to_dut[0];
            end
            if (_mode == 0 || _mode == 2) begin
                bit_cnt = 1;
            end else begin
                bit_cnt = 0;
            end
            mode = _mode;
            bit_order = _bit_order;
            start = 0;
            divisor = 10;
            delay_us = 1;
            rst = 1;
            #20
            rst = 0;
            start = 1;
        end
    endtask

    task finish_bench;
        begin
            #100;
            $finish;
        end
    endtask

endmodule
