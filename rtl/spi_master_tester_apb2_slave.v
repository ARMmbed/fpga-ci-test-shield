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

// SPI master tester module
//
// This modules contains a SPI slave and is used for testing
// a SPI master. It supports all SPI clock modes, symbols sizes in range 1-32, bit ordering (MSB/LSB first).
//
// APB interface:
// Addr     Size    Name                                                                 Type
// +0       4       unused                                                               NA
// +4       4       unused                                                               NA
// +8       1       starts                                                               RO
// +9       1       stops                                                                RO
// +10      2       transfers                                                            RO
// +12      1       reserved (future - latch values)                                     RO
// +13      1       prev_to_slave_4[7:0]                                                 RO
// +14      1       prev_to_slave_3[7:0]                                                 RO
// +15      1       prev_to_slave_2[7:0]                                                 RO
// +16      1       prev_to_slave_1[7:0]                                                 RO
// +17      1       next_from_slave                                                      RW
// +18      4       to_slave_checksum                                                    RO
// +22      2       spi_slave_ctrl                                                       RW
// +24      2       hd_tx_cnt                                                            RW
// +26      2       hd_rx_cnt                                                            RW
// +28      4       cs_to_first_sclk_cnt                                                 RW
// +32      4       last_sclk_to_cs_cnt                                                  RW
// +36      4       prev_to_slave_4[31:0]                                                RO
// +40      4       prev_to_slave_3[31:0]                                                RO
// +44      4       prev_to_slave_2[31:0]                                                RO
// +48      4       prev_to_slave_1[31:0]                                                RO
//
//
module spi_master_tester_apb2_slave #(
        parameter IO_LOGICAL = 8
    )
    (
        input wire clk,
        input wire rst,
        input wire [IO_LOGICAL - 1:0] logical_in,
        output wire [IO_LOGICAL - 1:0] logical_val,
        output wire [IO_LOGICAL - 1:0] logical_drive,

        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output reg [DATA_BITS - 1:0] PRDATA
    );

    localparam ADDR_BITS = 12;
    localparam DATA_BITS = 8;

    localparam FULL_DUPLEX = 0;
    localparam HALF_DUPLEX = 1;
    localparam HD_PROC_RX = 1;
    localparam HD_PROC_TX = 0;

    // 8 - The number of times CS was asserted
    reg [7:0] starts;
    // 9 - The number of times CS was deasserted
    reg [7:0] stops;
    // 10 - The number of transfers
    reg [15:0] transfers;
    // 12 - Values at the respective event
    reg start_sclk; // bit 0
    reg start_sin;  // bit 1
    reg stop_sclk;  // bit 2
    reg stop_sin;   // bit 3
    // The last 4 bytes received
    reg [31:0] to_slave [0:3];
    // Starting value to output
    reg [31:0] next_from_slave;
    reg [31:0] to_slave_checksum;

    // spi_slave_ctrl:
    // - clk mode  [1:0]
    // - bit order [2]
    // - duplex    [3]
    // - sym size  [9:4]
    // - unused    [11:10]
    reg [15:0] spi_slave_ctrl;

    // RX/RX count for Half-Duplex mode
    reg [15:0] hd_tx_cnt;
    reg [15:0] hd_rx_cnt;

    // Clock ticks count to verify delay between CS assertion and first clock edge / last clock edge and CS de-asserion
    reg [31:0] cs_to_first_sclk_cnt;
    reg [31:0] last_sclk_to_cs_cnt;

    reg cs_to_first_sclk_active;
    reg cs_to_first_sclk_done;
    reg sclk_prev;

    wire[1:0] ctrl_clk_mode;
    wire ctrl_bit_order;         // MSB first = 0, LSB first = 1
    wire ctrl_duplex;            // Full = 0, Half = 1
    wire[5:0] ctrl_sym_size;

    assign ctrl_clk_mode = spi_slave_ctrl[1:0];
    assign ctrl_bit_order = spi_slave_ctrl[2];
    assign ctrl_duplex = spi_slave_ctrl[3];
    assign ctrl_sym_size = spi_slave_ctrl[9:4];

    wire hd_proc_rx_tx = (ctrl_duplex == HALF_DUPLEX && hd_rx_cnt != 0);
    wire hd_prep_tx_buf = (ctrl_duplex == HALF_DUPLEX && hd_rx_cnt == 1);

    wire sin;
    wire sout;
    wire sclk;
    wire scs;

    wire [31:0] dout;
    wire [31:0] din;

    wire start;
    wire next;
    wire stop;

    wire sclk_edge;

    // Map SPI pins
    assign sin = (ctrl_duplex == HALF_DUPLEX ? (hd_rx_cnt ? logical_in[0] : 0) : logical_in[0]);
    assign logical_val[0] = (ctrl_duplex == HALF_DUPLEX ? (hd_rx_cnt ? 1'b0 : sout) : 1'b0);
    assign logical_drive[0] = (ctrl_duplex == HALF_DUPLEX ? (hd_rx_cnt ? 0 : 1) : 0);

    assign logical_val[1] = (ctrl_duplex == HALF_DUPLEX ? 1'b0 : sout) ;
    assign logical_drive[1] = scs;
    assign sclk = logical_in[2];
    assign scs = !logical_in[3];

    // Set unused outputs low

    assign logical_val[IO_LOGICAL - 1:2] = 0;
    assign logical_drive[IO_LOGICAL - 1:2] = 0;

    assign dout = next_from_slave;

    assign sclk_edge = (sclk_prev != sclk);

    spi_slave #(.DATA_BUS_WIDTH(32)) spi_slave (clk, rst, sout, sin, sclk, scs, ctrl_clk_mode, ctrl_bit_order, ctrl_sym_size, dout, din, start, next, stop);

    always @(posedge clk) begin
        sclk_prev <= sclk;
        if (sclk_edge && scs == 1'b1) begin
                last_sclk_to_cs_cnt <= 32'd1;
        end else if (scs == 1'b1) begin
            last_sclk_to_cs_cnt <= last_sclk_to_cs_cnt + 1;
        end

        if (cs_to_first_sclk_done == 1'b0) begin
            if (cs_to_first_sclk_active == 1'b0 && scs == 1'b1) begin
                cs_to_first_sclk_active <= 1'b1;
            end

            if (cs_to_first_sclk_active == 1'b1 && scs == 1'b1) begin
                cs_to_first_sclk_cnt <= cs_to_first_sclk_cnt + 1;
            end

            if (cs_to_first_sclk_active == 1'b1 &&
                ((sclk == 1'b1 && (ctrl_clk_mode == 2'd0 || ctrl_clk_mode == 2'd1)) ||
                 (sclk == 1'b0 && (ctrl_clk_mode == 2'd2 || ctrl_clk_mode == 2'd3)))) begin
                cs_to_first_sclk_active <= 1'b0;
                cs_to_first_sclk_done <= 1'b1;
            end
        end

        if (rst) begin
            starts <= 0;
            stops <= 0;
            transfers <= 0;
            start_sclk <= 0;
            start_sin <= 0;
            stop_sclk <= 0;
            stop_sin <= 0;
            to_slave[0] <= 0;
            to_slave[1] <= 0;
            to_slave[2] <= 0;
            to_slave[3] <= 0;
            next_from_slave <= 0;
            to_slave_checksum <= 0;
            sclk_prev <= sclk;
            cs_to_first_sclk_active <= 1'b0;
            cs_to_first_sclk_done <= 1'b0;
            cs_to_first_sclk_cnt <= 32'd0;
            last_sclk_to_cs_cnt <= 32'd0;
        end else begin
            if (start) begin
                starts <= starts + 1;
                start_sclk <= sclk;
                start_sin <= sin;
                if (ctrl_duplex == FULL_DUPLEX) begin
                    next_from_slave <= next_from_slave + 1;
                end
            end
            if (next) begin
                transfers <= transfers + 1;

                if ((ctrl_duplex == FULL_DUPLEX) || (hd_proc_rx_tx == HD_PROC_TX) || hd_prep_tx_buf) begin
                    next_from_slave <= next_from_slave + 1;
                end

                if ((ctrl_duplex == FULL_DUPLEX) || (hd_proc_rx_tx == HD_PROC_RX)) begin
                    to_slave_checksum <= to_slave_checksum + din;

                    to_slave[0] <= to_slave[1];
                    to_slave[1] <= to_slave[2];
                    to_slave[2] <= to_slave[3];
                    to_slave[3] <= din;
                end

                // half-duplex mode
                if (ctrl_duplex == HALF_DUPLEX) begin
                    if (hd_proc_rx_tx == HD_PROC_RX) begin
                        hd_rx_cnt <= hd_rx_cnt - 1;
                    end
                    if (hd_tx_cnt && (hd_proc_rx_tx == HD_PROC_TX)) begin
                        hd_tx_cnt <= hd_tx_cnt - 1;
                    end
                end
            end
            if (stop) begin
                stops <= stops + 1;
                stop_sclk <= sclk;
                stop_sin <= sin;
                // No more bytes are going to be sent so undo that last increment
                if (ctrl_duplex == FULL_DUPLEX) begin
                    next_from_slave <= next_from_slave - 1;
                end
            end

            // APB interface
            if (PSEL) begin
                if (PWRITE && PENABLE) begin
                    case (PADDR)
                        // Writeable values
                       17: next_from_slave     <= PWDATA;
                       22: spi_slave_ctrl[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       23: spi_slave_ctrl[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

                       24: hd_tx_cnt[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                       25: hd_tx_cnt[DATA_BITS * 1+:DATA_BITS] <= PWDATA;

                       26: hd_rx_cnt[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       27: hd_rx_cnt[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

                       28: cs_to_first_sclk_cnt[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       29: cs_to_first_sclk_cnt[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;
                       30: cs_to_first_sclk_cnt[DATA_BITS * 2+:DATA_BITS]  <= PWDATA;
                       31: cs_to_first_sclk_cnt[DATA_BITS * 3+:DATA_BITS]  <= PWDATA;

                       32: last_sclk_to_cs_cnt[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       33: last_sclk_to_cs_cnt[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;
                       34: last_sclk_to_cs_cnt[DATA_BITS * 2+:DATA_BITS]  <= PWDATA;
                       35: last_sclk_to_cs_cnt[DATA_BITS * 3+:DATA_BITS]  <= PWDATA;

                        default:;
                    endcase
                end
                if (!PWRITE) begin
                    case (PADDR)
                        // Readable values
                        8: PRDATA <= starts;
                        9: PRDATA <= stops;
                       10: PRDATA <= transfers[DATA_BITS * 0+:DATA_BITS];
                       11: PRDATA <= transfers[DATA_BITS * 1+:DATA_BITS];
                       12: PRDATA <= {4'h0, stop_sin, stop_sclk, start_sin, start_sclk};

                       13: PRDATA <= to_slave[0][7:0];
                       14: PRDATA <= to_slave[1][7:0];
                       15: PRDATA <= to_slave[2][7:0];
                       16: PRDATA <= to_slave[3][7:0];

                       17: PRDATA <= next_from_slave;

                       18: PRDATA <= to_slave_checksum[DATA_BITS * 0+:DATA_BITS];
                       19: PRDATA <= to_slave_checksum[DATA_BITS * 1+:DATA_BITS];
                       20: PRDATA <= to_slave_checksum[DATA_BITS * 2+:DATA_BITS];
                       21: PRDATA <= to_slave_checksum[DATA_BITS * 3+:DATA_BITS];

                       22: PRDATA <= spi_slave_ctrl[DATA_BITS * 0+:DATA_BITS];
                       23: PRDATA <= spi_slave_ctrl[DATA_BITS * 1+:DATA_BITS];

                       24: PRDATA <= hd_tx_cnt[DATA_BITS * 0+:DATA_BITS];
                       25: PRDATA <= hd_tx_cnt[DATA_BITS * 1+:DATA_BITS];

                       26: PRDATA <= hd_rx_cnt[DATA_BITS * 0+:DATA_BITS];
                       27: PRDATA <= hd_rx_cnt[DATA_BITS * 1+:DATA_BITS];

                       28: PRDATA <= cs_to_first_sclk_cnt[DATA_BITS * 0+:DATA_BITS];
                       29: PRDATA <= cs_to_first_sclk_cnt[DATA_BITS * 1+:DATA_BITS];
                       30: PRDATA <= cs_to_first_sclk_cnt[DATA_BITS * 2+:DATA_BITS];
                       31: PRDATA <= cs_to_first_sclk_cnt[DATA_BITS * 3+:DATA_BITS];

                       32: PRDATA <= last_sclk_to_cs_cnt[DATA_BITS * 0+:DATA_BITS];
                       33: PRDATA <= last_sclk_to_cs_cnt[DATA_BITS * 1+:DATA_BITS];
                       34: PRDATA <= last_sclk_to_cs_cnt[DATA_BITS * 2+:DATA_BITS];
                       35: PRDATA <= last_sclk_to_cs_cnt[DATA_BITS * 3+:DATA_BITS];

                       36: PRDATA <= to_slave[0][DATA_BITS * 0+:DATA_BITS];
                       37: PRDATA <= to_slave[0][DATA_BITS * 1+:DATA_BITS];
                       38: PRDATA <= to_slave[0][DATA_BITS * 2+:DATA_BITS];
                       39: PRDATA <= to_slave[0][DATA_BITS * 3+:DATA_BITS];

                       40: PRDATA <= to_slave[1][DATA_BITS * 0+:DATA_BITS];
                       41: PRDATA <= to_slave[1][DATA_BITS * 1+:DATA_BITS];
                       42: PRDATA <= to_slave[1][DATA_BITS * 2+:DATA_BITS];
                       43: PRDATA <= to_slave[1][DATA_BITS * 3+:DATA_BITS];

                       44: PRDATA <= to_slave[2][DATA_BITS * 0+:DATA_BITS];
                       45: PRDATA <= to_slave[2][DATA_BITS * 1+:DATA_BITS];
                       46: PRDATA <= to_slave[2][DATA_BITS * 2+:DATA_BITS];
                       47: PRDATA <= to_slave[2][DATA_BITS * 3+:DATA_BITS];

                       48: PRDATA <= to_slave[3][DATA_BITS * 0+:DATA_BITS];
                       49: PRDATA <= to_slave[3][DATA_BITS * 1+:DATA_BITS];
                       50: PRDATA <= to_slave[3][DATA_BITS * 2+:DATA_BITS];
                       51: PRDATA <= to_slave[3][DATA_BITS * 3+:DATA_BITS];

                        default: PRDATA <= 0;
                    endcase
                end
            end


        end
    end

endmodule
