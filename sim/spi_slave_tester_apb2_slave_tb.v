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

module spi_slave_tester_apb2_slave_tb;
    parameter ADDR_BITS = 12;
    parameter DATA_BITS = 8;
    parameter IO_LOGICAL = 8;

    localparam READ_COUNT = 22;

    localparam STARTS_ADDR = 8;
    localparam STOPS_ADDR = 9;
    localparam TRANSFERS_ADDR = 10;
    localparam PREV_DATA_4_ADDR = 13;
    localparam PREV_DATA_3_ADDR = 14;
    localparam PREV_DATA_2_ADDR = 15;
    localparam PREV_DATA_1_ADDR = 16;
    localparam NEXT_FROM_MASTER_ADDR = 17;
    localparam TO_MASTER_CHECKSUM_ADDR = 21;
    localparam SPI_SLAVE_CTRL = 25;
    localparam HD_TX_CNT = 27;
    localparam HD_RX_CNT = 29;
    localparam SPI_CLK_DIV = 31;
    localparam SPI_NUM_OF_SYM = 33;
    localparam SPI_START_DELAY = 35;
    localparam SPI_SYM_DELAY = 36;

    reg clk, rst;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    reg [7:0] from_spi;
    reg [7:0] to_spi;
    reg [7:0] to_spi_org;

    wire sout, sin, sclk, scs;

    wire hd_tx_rx;

    wire [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] logical_val;
    wire [IO_LOGICAL - 1:0] logical_drive;

    integer i;
    reg [31:0] expected_to_slave_checksum;
    reg [31:0] expected_next_from_master;

    reg [7:0] data;
    reg [15:0] data_16;
    reg [7:0] test_bit_cnt;
    reg [15:0] hd_sym_cnt;
    reg [15:0] hd_num_of_sym;
    reg [31:0] to_master_checksum;
    reg count_start_cs_delay;
    reg [31:0] delay_clk_ticks_cnt;
    reg [31:0] cs_clk_ticks_cnt;

    reg hd_mode;

    assign logical_in = hd_mode ? {4'h0, 1'h0, 1'h0, 1'h0, sin} : {4'h0, 1'h0, 1'h0, sin, 1'h1};
    assign sout = logical_val[0] && logical_drive[0];
    assign sclk = logical_val[2];
    assign scs = logical_val[3];

    assign sin = to_spi[7];
    assign hd_tx_rx = (hd_sym_cnt < (hd_num_of_sym / 2));

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    spi_slave_tester_apb2_slave #(.IO_LOGICAL(8)) spi_slave_tester_apb2_slave(
        .clk(clk),
        .rst(rst),

        .logical_in(logical_in),
        .logical_val(logical_val),
        .logical_drive(logical_drive),

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

    always @(negedge sclk) begin
        // Check that the data is valid
        if (!scs) begin

            if (hd_mode == 0 || (hd_mode == 1 && hd_tx_rx == 0)) begin
                to_spi <= (to_spi << 1);
            end;

            test_bit_cnt <= test_bit_cnt + 1;

            if (test_bit_cnt == 7) begin
                test_bit_cnt <= 0;

                if (hd_mode == 1) begin
                    hd_sym_cnt <= hd_sym_cnt + 1;
                end

                if (hd_mode == 0 || (hd_mode == 1 && hd_tx_rx == 0)) begin
                    to_spi <= (to_spi_org - 1);
                    to_spi_org <= (to_spi_org - 1);
                end

                if (hd_mode == 0 || (hd_mode == 1 && hd_tx_rx == 1)) begin
                    `util_assert_equal(expected_next_from_master, from_spi);
                    //$display("from_spi: 0x%X expected_next_from_master: 0x%X", from_spi, expected_next_from_master);
                    from_spi <= 0;
                    if (expected_next_from_master < 255)
                        expected_next_from_master = expected_next_from_master + 1;
                    else expected_next_from_master = 0;
                end
            end

        end
    end

    always @(posedge sclk) begin
        // Check that the data is valid
        if (!scs) begin
            if (hd_mode == 0 || (hd_mode == 1 && hd_tx_rx == 1)) begin
                from_spi <= (from_spi << 1) | sout;
            end
        end
    end

    always @(posedge clk) begin
        // Check that the data is valid
        if (scs && count_start_cs_delay) begin
            delay_clk_ticks_cnt <= delay_clk_ticks_cnt + 1;
        end

        if (!scs) begin
            cs_clk_ticks_cnt <= cs_clk_ticks_cnt + 1;
        end
    end

    always @(negedge scs) begin
        // Check that the data is valid
        count_start_cs_delay <= 0;
    end

    task reset_spi;
        input integer reset_time;
        begin
            @(negedge clk);
            rst <= 1;
            #(reset_time);
            @(negedge clk);
            rst <= 0;
        end
    endtask

    task spi_transfer;
        input reg [15:0] test_num_of_symbols;
        input reg [7:0] test_next_from_spi_master;
        input reg [7:0] test_next_to_spi_master;
        input reg [7:0] test_start_delay_us;
        input reg [15:0] test_clk_div;
    begin
        count_start_cs_delay = 0;
        hd_sym_cnt = 0;
        hd_num_of_sym = test_num_of_symbols;

        // Configure spi master (default format)
        if (hd_mode == 1) begin
            apb2_slave_tester.write(SPI_SLAVE_CTRL, 8'b10001000);
        end else begin
            apb2_slave_tester.write(SPI_SLAVE_CTRL, 8'b10000000);
        end
        apb2_slave_tester.write(SPI_SLAVE_CTRL + 1, 8'b00000000);

        apb2_slave_tester.write(SPI_CLK_DIV, test_clk_div[7:0]);
        apb2_slave_tester.write(SPI_CLK_DIV + 1, test_clk_div[15:8]);
        apb2_slave_tester.write(SPI_NUM_OF_SYM, test_num_of_symbols[7:0]);
        apb2_slave_tester.write(SPI_NUM_OF_SYM+1, test_num_of_symbols[15:8]);
        apb2_slave_tester.write(SPI_START_DELAY, test_start_delay_us);
        apb2_slave_tester.write(SPI_SYM_DELAY, 0);
        apb2_slave_tester.write(SPI_SYM_DELAY + 1, 0);

        apb2_slave_tester.write(HD_TX_CNT, hd_num_of_sym / 2);
        apb2_slave_tester.write(HD_RX_CNT, hd_num_of_sym / 2);

        reset_spi(20);
        expected_next_from_master = test_next_from_spi_master;

        // Check regs after reset
        for (i = 0; i < READ_COUNT; i = i + 1) begin
            apb2_slave_tester.read(i, data);
            `util_assert_equal(0, data);
        end

        // calculate expected checksum
        expected_to_slave_checksum = 0;
        data = test_next_to_spi_master;
        for (i = 0; i < (test_num_of_symbols / (hd_mode + 1)); i = i + 1) begin
            expected_to_slave_checksum = (expected_to_slave_checksum + data);
            data = data - 1;
        end

        apb2_slave_tester.read(SPI_SLAVE_CTRL, data);
        if (hd_mode == 1) begin
            `util_assert_equal(8'b10001000, data);
        end else begin
            `util_assert_equal(8'b10000000, data);
        end
        apb2_slave_tester.read(SPI_SLAVE_CTRL + 1, data);
        `util_assert_equal(8'b00000000, data);
        apb2_slave_tester.read(SPI_CLK_DIV, data);
        `util_assert_equal(test_clk_div[7:0], data);
        apb2_slave_tester.read(SPI_CLK_DIV + 1, data);
        `util_assert_equal(test_clk_div[15:8], data);
        apb2_slave_tester.read(SPI_NUM_OF_SYM, data);
        `util_assert_equal(test_num_of_symbols[7:0], data);
        apb2_slave_tester.read(SPI_NUM_OF_SYM + 1, data);
        `util_assert_equal(test_num_of_symbols[15:8], data);
        apb2_slave_tester.read(SPI_START_DELAY, data);
        `util_assert_equal(test_start_delay_us, data);
        apb2_slave_tester.read(SPI_SYM_DELAY, data);
        `util_assert_equal(0, data);
        apb2_slave_tester.read(SPI_SYM_DELAY + 1, data);
        `util_assert_equal(0, data);

        // Init reg which dolds data to by sent by spi master
        apb2_slave_tester.write(NEXT_FROM_MASTER_ADDR, test_next_from_spi_master);

        // Init test variables
        to_spi = test_next_to_spi_master;
        to_spi_org = to_spi;
        from_spi = 8'd0;
        test_bit_cnt = 0;

        // Trigger start spi transmission
        delay_clk_ticks_cnt = 0;
        cs_clk_ticks_cnt = 0;
        apb2_slave_tester.write(SPI_SLAVE_CTRL + 1, 8'b00000100);
        count_start_cs_delay = 1;

        // Wait until the end of the transmission
        #(1000 + test_num_of_symbols * 8 * 10 * test_clk_div + test_start_delay_us * 100 * 10);

        // Check registers
        apb2_slave_tester.read(SPI_SLAVE_CTRL, data);
        if (hd_mode == 1) begin
            `util_assert_equal(8'b10001000, data);
        end else begin
            `util_assert_equal(8'b10000000, data);
        end
        apb2_slave_tester.read(SPI_SLAVE_CTRL + 1, data);
        `util_assert_equal(8'b00000000, data); // start request bit should be cleared
        apb2_slave_tester.read(STARTS_ADDR, data);
        `util_assert_equal(1, data);
        apb2_slave_tester.read(STOPS_ADDR, data);
        `util_assert_equal(1, data);
        apb2_slave_tester.read(TRANSFERS_ADDR, data);
        `util_assert_equal(test_num_of_symbols[7:0], data);
        apb2_slave_tester.read(TRANSFERS_ADDR + 1, data);
        `util_assert_equal(test_num_of_symbols[15:8], data);
        apb2_slave_tester.read(TO_MASTER_CHECKSUM_ADDR + 0, to_master_checksum[0 * 8+:8]);
        apb2_slave_tester.read(TO_MASTER_CHECKSUM_ADDR + 1, to_master_checksum[1 * 8+:8]);
        apb2_slave_tester.read(TO_MASTER_CHECKSUM_ADDR + 2, to_master_checksum[2 * 8+:8]);
        apb2_slave_tester.read(TO_MASTER_CHECKSUM_ADDR + 3, to_master_checksum[3 * 8+:8]);
        `util_assert_equal(expected_to_slave_checksum, to_master_checksum);
        apb2_slave_tester.read(SPI_NUM_OF_SYM, data);
        `util_assert_equal(test_num_of_symbols[7:0], data);
        apb2_slave_tester.read(SPI_NUM_OF_SYM + 1, data);
        `util_assert_equal(test_num_of_symbols[15:8], data);

        `util_assert(delay_clk_ticks_cnt >= (test_start_delay_us * 100));

        // symbol size * number of symbols * test_clk_div + half clock period betwwen cs assertion and first sclk edge +
        // half clock period betwwen last sclk edge and cs de-asserion
        `util_assert_equal(8 * test_num_of_symbols * test_clk_div + test_clk_div, cs_clk_ticks_cnt);
    end
    endtask

    task normal_operation_testcase;
        begin
            // params: mun of symbols / from spi master / to spi master / start delay / clk div
            spi_transfer(8'd3, 8'h55, 8'hAA, 8'd1, 16'd10);
            spi_transfer(8'd5, 8'h00, 8'hFF, 8'd2, 16'd20);
            spi_transfer(8'd7, 8'h11, 8'h22, 8'd3, 16'd30);
            spi_transfer(16'd300, 8'hFF, 8'h00, 8'd1, 16'd10);
        end
    endtask

    task half_duplex_testcase;
        begin
            // params: mun of symbols / from spi master / to spi master / start delay / clk div
            spi_transfer(8'd10, 8'h55, 8'hAA, 8'd1, 16'd10);
            spi_transfer(8'd20, 8'h00, 8'hFF, 8'd2, 16'd20);
        end
    endtask

    initial begin
        clk = 0;
        rst = 0;
    end

    event terminate_sim;
    initial begin
        @terminate_sim;
        #200 $finish;
    end

    initial begin
        hd_mode = 0;
        normal_operation_testcase();
        hd_mode = 1;
        half_duplex_testcase();
        -> terminate_sim;
    end

endmodule
