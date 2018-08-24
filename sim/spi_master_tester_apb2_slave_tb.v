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

module spi_master_tester_apb2_slave_tb;
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
    localparam NEXT_FROM_SLAVE_ADDR = 17;
    localparam TO_SLAVE_CHECKSUM_ADDR = 18;
    localparam SPI_SLAVE_CTRL = 22;
    localparam HD_TX_CNT = 24;
    localparam HD_RX_CNT = 26;
    localparam CS_TO_CLK_CNT = 28;
    localparam CLK_TO_CS_CNT = 32;

    reg clk, rst;

    integer i;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    reg scs;
    wire sout, sin, sclk;

    reg hf_mode;

    wire [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] logical_val;
    wire [IO_LOGICAL - 1:0] logical_drive;

    assign logical_in = {4'h0, scs, sclk, 1'h0, sin};
    assign sout = hf_mode ? (logical_val[0] && logical_drive[0]) : (logical_val[1] && logical_drive[1]);

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
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

    spi_master_tester_apb2_slave #(.IO_LOGICAL(8)) spi_master_tester_apb2_slave(
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

    initial begin
        clk = 0;
        rst = 0;
        scs = 1;
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
        reg [7:0] data;
        reg [7:0] data_from_spi;
        reg [7:0] expected_next_from_slave;
        reg [15:0] transfers;
        reg [31:0] to_slave_checksum;
        reg [31:0] cs_edge_to_first_sclk_edge_cnt;
        reg [31:0] last_sclk_edge_to_cs_edge_cnt;
        integer expected_starts;
        integer expected_stops;
        integer expected_transfers;
        integer expected_to_slave_checksum;
        integer expected_hd_rx_cnt;
        integer expected_hd_tx_cnt;
        begin
            // Mode 0/MSB firts/8 bit sym/full duplex
            apb2_slave_tester.write(SPI_SLAVE_CTRL, 8'b10000000);
            apb2_slave_tester.write(SPI_SLAVE_CTRL + 1, 8'b00000000);

            reset(20);
            expected_next_from_slave = 0;
            expected_starts = 0;
            expected_stops = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;

            // Check that everything is initialized to 0
            `util_assert_equal(0, logical_val);
            `util_assert_equal(0, logical_drive);
            for (i = 0; i < READ_COUNT; i = i + 1) begin
                apb2_slave_tester.read(i, data);
                `util_assert_equal(0, data);
            end

            // Test delay between spi clock start/stop and chip select asserion/de-assertion
            @(posedge clk);
            scs = 0;
            #(100);

            spi.transfer(0, data_from_spi);

            #(100);
            @(posedge clk);
            scs = 1;

            apb2_slave_tester.read(CS_TO_CLK_CNT + 0, cs_edge_to_first_sclk_edge_cnt[0 * 8+:8]);
            apb2_slave_tester.read(CS_TO_CLK_CNT + 1, cs_edge_to_first_sclk_edge_cnt[1 * 8+:8]);
            apb2_slave_tester.read(CS_TO_CLK_CNT + 2, cs_edge_to_first_sclk_edge_cnt[2 * 8+:8]);
            apb2_slave_tester.read(CS_TO_CLK_CNT + 3, cs_edge_to_first_sclk_edge_cnt[3 * 8+:8]);

            apb2_slave_tester.read(CLK_TO_CS_CNT + 0, last_sclk_edge_to_cs_edge_cnt[0 * 8+:8]);
            apb2_slave_tester.read(CLK_TO_CS_CNT + 1, last_sclk_edge_to_cs_edge_cnt[1 * 8+:8]);
            apb2_slave_tester.read(CLK_TO_CS_CNT + 2, last_sclk_edge_to_cs_edge_cnt[2 * 8+:8]);
            apb2_slave_tester.read(CLK_TO_CS_CNT + 3, last_sclk_edge_to_cs_edge_cnt[3 * 8+:8]);

            // Delay is equal to 100 => 10 clk ticks
            // Half period before spi.transfer starts clocking which gives additional 50 delay => 5 clk ticks
            `util_assert_equal(15, cs_edge_to_first_sclk_edge_cnt);
            `util_assert_equal(10, last_sclk_edge_to_cs_edge_cnt);

            reset(20);
            expected_next_from_slave = 0;
            expected_starts = 0;
            expected_stops = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;

            // Check that everything is initialized to 0
            `util_assert_equal(0, logical_val);
            `util_assert_equal(0, logical_drive);
            for (i = 0; i < READ_COUNT; i = i + 1) begin
                apb2_slave_tester.read(i, data);
                `util_assert_equal(0, data);
            end

            @(negedge clk);
            scs = 0;
            expected_starts = expected_starts + 1;
            #(100);
            @(negedge clk);

            // Check counts
            apb2_slave_tester.read(STARTS_ADDR, data);
            `util_assert_equal(expected_starts, data);
            apb2_slave_tester.read(STOPS_ADDR, data);
            `util_assert_equal(expected_stops, data);
            apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
            apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
            `util_assert_equal(expected_transfers, transfers);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
            `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);

            for (i = 0; i < 300; i = i + 1) begin
                // Transfer and check expected data
                spi.transfer(i, data_from_spi);
                `util_assert_equal(expected_next_from_slave, data_from_spi);
                expected_to_slave_checksum = expected_to_slave_checksum + (i & 'hFF);
                expected_next_from_slave = expected_next_from_slave + 1;
                expected_transfers = expected_transfers + 1;

                // Check counts
                apb2_slave_tester.read(STARTS_ADDR, data);
                `util_assert_equal(expected_starts, data);
                apb2_slave_tester.read(STOPS_ADDR, data);
                `util_assert_equal(expected_stops, data);
                apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
                apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
                `util_assert_equal(expected_transfers, transfers);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
                `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);
            end

            @(negedge clk);
            scs = 1;
            expected_stops = expected_stops + 1;
            #(100);
            @(negedge clk);

            // Check counts
            apb2_slave_tester.read(STARTS_ADDR, data);
            `util_assert_equal(expected_starts, data);
            apb2_slave_tester.read(STOPS_ADDR, data);
            `util_assert_equal(expected_stops, data);
            apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
            apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
            `util_assert_equal(expected_transfers, transfers);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
            `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);

            // Check last 4 values written
            apb2_slave_tester.read(PREV_DATA_1_ADDR, data);
            `util_assert_equal((i - 1) & 'hFF, data);
            apb2_slave_tester.read(PREV_DATA_2_ADDR, data);
            `util_assert_equal((i - 2) & 'hFF, data);
            apb2_slave_tester.read(PREV_DATA_3_ADDR, data);
            `util_assert_equal((i - 3) & 'hFF, data);
            apb2_slave_tester.read(PREV_DATA_4_ADDR, data);
            `util_assert_equal((i - 4) & 'hFF, data);

            // Transfer and check expected data
            for (i = 0; i < 10; i = i + 1) begin
                // Set a new random value
                expected_next_from_slave = $random;
                apb2_slave_tester.write(NEXT_FROM_SLAVE_ADDR, expected_next_from_slave);

                @(negedge clk);
                scs = 0;
                expected_starts = expected_starts + 1;
                #(100);
                @(negedge clk);

                spi.transfer(i, data_from_spi);
                `util_assert_equal(expected_next_from_slave, data_from_spi);
                 expected_to_slave_checksum = expected_to_slave_checksum + (i & 'hFF);
                expected_next_from_slave = expected_next_from_slave + 1;
                expected_transfers = expected_transfers + 1;

                // Check counts
                apb2_slave_tester.read(STARTS_ADDR, data);
                `util_assert_equal(expected_starts, data);
                apb2_slave_tester.read(STOPS_ADDR, data);
                `util_assert_equal(expected_stops, data);
                apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
                apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
                `util_assert_equal(expected_transfers, transfers);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
                `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);

                // Ensure value increments
                apb2_slave_tester.write(NEXT_FROM_SLAVE_ADDR, expected_next_from_slave);
                spi.transfer(i, data_from_spi);
                `util_assert_equal(expected_next_from_slave, data_from_spi);
                expected_to_slave_checksum = expected_to_slave_checksum + (i & 'hFF);
                expected_next_from_slave = expected_next_from_slave + 1;
                expected_transfers = expected_transfers + 1;

                // Check counts
                apb2_slave_tester.read(STARTS_ADDR, data);
                `util_assert_equal(expected_starts, data);
                apb2_slave_tester.read(STOPS_ADDR, data);
                `util_assert_equal(expected_stops, data);
                apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
                apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
                `util_assert_equal(expected_transfers, transfers);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
                `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);

                @(negedge clk);
                scs = 1;
                expected_stops = expected_stops + 1;
                #(100);
                @(negedge clk);
            end

            // Make sure everything resets
            reset(20);
            expected_starts = 0;
            expected_stops = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;

            // Check that everything is initialized to 0
            `util_assert_equal(0, logical_val);
            `util_assert_equal(0, logical_drive);
            for (i = 0; i < READ_COUNT; i = i + 1) begin
                apb2_slave_tester.read(i, data);
                `util_assert_equal(0, data);
            end
        end
    endtask

    task half_duplex_operation_testcase;
        reg [7:0] data;
        reg [7:0] data_from_spi;
        reg [7:0] expected_next_from_slave;
        reg [15:0] transfers;
        reg [31:0] to_slave_checksum;
        integer expected_starts;
        integer expected_stops;
        integer expected_transfers;
        integer expected_to_slave_checksum;
        integer expected_hd_rx_cnt;
        integer expected_hd_tx_cnt;
        begin
            // Mode 0/MSB firts/8 bit sym/full duplex
            apb2_slave_tester.write(SPI_SLAVE_CTRL, 8'b10001000);
            apb2_slave_tester.write(SPI_SLAVE_CTRL + 1, 8'b00000000);
            apb2_slave_tester.write(SPI_SLAVE_CTRL + 2, 8'b00000000);

            apb2_slave_tester.write(HD_TX_CNT, 8'd5);
            apb2_slave_tester.write(HD_TX_CNT + 1, 8'd0);
            apb2_slave_tester.write(HD_RX_CNT, 8'd5);
            apb2_slave_tester.write(HD_RX_CNT + 1, 8'd0);

            reset(20);
            expected_next_from_slave = 0;
            expected_starts = 0;
            expected_stops = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;
            expected_hd_rx_cnt = 5;
            expected_hd_tx_cnt = 5;

            // Check that everything is initialized to 0
            `util_assert_equal(0, logical_val);
            `util_assert_equal(0, logical_drive);
            for (i = 0; i < READ_COUNT; i = i + 1) begin
                apb2_slave_tester.read(i, data);
                `util_assert_equal(0, data);
            end

            // Check counts
            apb2_slave_tester.read(STARTS_ADDR, data);
            `util_assert_equal(expected_starts, data);
            apb2_slave_tester.read(STOPS_ADDR, data);
            `util_assert_equal(expected_stops, data);
            apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
            apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
            `util_assert_equal(expected_transfers, transfers);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
            `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);
            apb2_slave_tester.read(HD_RX_CNT, data);
            `util_assert_equal(expected_hd_rx_cnt, data);
            apb2_slave_tester.read(HD_TX_CNT, data);
            `util_assert_equal(expected_hd_tx_cnt, data);

            @(negedge clk);
            scs = 0;

            for (i = 0; i < 10; i = i + 1) begin
                // Transfer and check expected data
                spi.transfer(i, data_from_spi);

                `util_assert_equal(expected_next_from_slave, data_from_spi);
                expected_transfers = expected_transfers + 1;
                if (i < 5) begin
                    expected_to_slave_checksum = expected_to_slave_checksum + (i & 'hFF);
                    expected_hd_rx_cnt = expected_hd_rx_cnt -1;
                end
                if (i > 4) begin
                    expected_next_from_slave = expected_next_from_slave + 1;
                    expected_hd_tx_cnt = expected_hd_tx_cnt -1;
                end

                // Check counts
                apb2_slave_tester.read(STARTS_ADDR, data);
                `util_assert_equal(1, data);
                apb2_slave_tester.read(STOPS_ADDR, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read(TRANSFERS_ADDR + 0, transfers[0 * 8+:8]);
                apb2_slave_tester.read(TRANSFERS_ADDR + 1, transfers[1 * 8+:8]);
                `util_assert_equal(expected_transfers, transfers);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 0, to_slave_checksum[0 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 1, to_slave_checksum[1 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 2, to_slave_checksum[2 * 8+:8]);
                apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR + 3, to_slave_checksum[3 * 8+:8]);
                `util_assert_equal(expected_to_slave_checksum, to_slave_checksum);
                apb2_slave_tester.read(HD_RX_CNT, data);
                `util_assert_equal(expected_hd_rx_cnt, data);
                apb2_slave_tester.read(HD_TX_CNT, data);
                `util_assert_equal(expected_hd_tx_cnt, data);
            end

            @(negedge clk);
            scs = 1;

            // Check counts
            apb2_slave_tester.read(STARTS_ADDR, data);
            `util_assert_equal(1, data);
            apb2_slave_tester.read(STOPS_ADDR, data);
            `util_assert_equal(1, data);

            // Make sure everything resets
            apb2_slave_tester.write(SPI_SLAVE_CTRL, 8'b10000000);
            apb2_slave_tester.write(SPI_SLAVE_CTRL + 1, 8'b00000000);
            apb2_slave_tester.write(SPI_SLAVE_CTRL + 2, 8'b00000000);

            apb2_slave_tester.write(HD_TX_CNT, 8'd0);
            apb2_slave_tester.write(HD_RX_CNT, 8'd0);

            reset(20);
            expected_starts = 0;
            expected_stops = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;

            // Check that everything is initialized to 0
            `util_assert_equal(0, logical_val);
            `util_assert_equal(0, logical_drive);
            for (i = 0; i < READ_COUNT; i = i + 1) begin
                apb2_slave_tester.read(i, data);
                `util_assert_equal(0, data);
            end

        end
    endtask

    initial begin
        hf_mode = 0;
        normal_operation_testcase();
        hf_mode = 1;
        half_duplex_operation_testcase();
        -> terminate_sim;
    end

endmodule
