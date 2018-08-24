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

// SPI slave tester module
//
// This modules contains a SPI master and is used for testing
// a SPI slave. It supports all SPI clock modes, symbols sizes in range 1-32, bit ordering (MSB/LSB first).
//
// APB interface:
// Addr     Size    Name                                                                 Type
// +0       4       unused                                                               RO
// +4       4       unused                                                               RO
// +8       1       starts                                                               RO
// +9       1       stops                                                                RO
// +10      2       transfers                                                            RO
// +12      1       reserved (future - latch values)                                     RO
// +13      1       prev_to_master_4[7:0]                                                RO
// +14      1       prev_to_master_3[7:0]                                                RO
// +15      1       prev_to_master_2[7:0]                                                RO
// +16      1       prev_to_master_1[7:0]                                                RO
// +17      4       next_from_master                                                     RW
// +21      4       to_master_checksum                                                   RO
// +25      2       spi_slave_ctrl                                                       RW
// +27      2       hd_tx_cnt                                                            RW
// +29      2       hd_rx_cnt                                                            RW
// +31      2       clk_divisor                                                          RW
// +33      2       num_of_symbols                                                       RW
// +35      1       start_delay_us                                                       RW
// +36      2       sym_delay_ticks                                                      RW
// +40      4       prev_to_master_4[31:0]                                               RO
// +44      4       prev_to_master_3[31:0]                                               RO
// +48      4       prev_to_master_2[31:0]                                               RO
// +52      4       prev_to_master_1[31:0]                                               RO
//
module spi_slave_tester_apb2_slave #(
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
    localparam HD_PROC_RX = 0;
    localparam HD_PROC_TX = 1;

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
    reg [31:0] to_master [0:3];
    // Starting value to output
    reg [31:0] next_from_master;
    reg [31:0] to_master_checksum;

    // 25 - spi ctrl reg
    // spi_slave_ctrl:
    // - clk mode           [1:0]
    // - bit order            [2]
    // - duplex               [3]
    // - sym size           [9:4]
    // - start_request       [10]
    // - unused           [15:11]
    reg [15:0] spi_slave_ctrl;

    // 27 - number of tx symbols (used only in half duplex mode)
    reg [15:0] hd_tx_cnt;
    // 29 - number of rx symbols (used only in half duplex mode)
    reg [15:0] hd_rx_cnt;
    // 31 - base clock divisor for sclk generation
    reg [15:0] clk_divisor;

    // 33 - number of symbols to be transmitted
    reg [15:0] num_of_symbols;

    // 35 - delay in us between start request and transmission start
    reg [7:0] start_delay_us;

    // 36 - delay in ticks between symbols transmission
    reg [15:0] sym_delay_ticks;

    reg scs_prev;

    wire[1:0] ctrl_clk_mode;
    wire ctrl_bit_order;         // MSB first = 0, LSB first = 1
    wire ctrl_duplex;            // Full = 0, Half = 1
    wire[5:0] ctrl_sym_size;
    wire[7:0] ctrl_start_delay_us;

    wire start_request;
    wire df_mode;
    wire hd_tx_rx;
    wire next;
    wire start;
    wire stop;

    wire sin;
    wire sout;
    wire sclk;
    wire scs;

    wire [31:0] dout;
    wire [31:0] din;

    assign ctrl_clk_mode = spi_slave_ctrl[1:0];
    assign ctrl_bit_order = spi_slave_ctrl[2];
    assign ctrl_duplex = spi_slave_ctrl[3];
    assign ctrl_sym_size = spi_slave_ctrl[9:4];
    assign start_request = spi_slave_ctrl[10];
    assign df_mode = spi_slave_ctrl[3];

    wire hd_proc_tx_rx = (ctrl_duplex == HALF_DUPLEX && hd_tx_rx);

    // Map SPI pins
    assign sin = (ctrl_duplex == HALF_DUPLEX ? (hd_tx_rx ? 1'b0 : logical_in[0]) : logical_in[1]);
    assign logical_val[0] = (ctrl_duplex == HALF_DUPLEX ? (hd_tx_rx ? sout : 1'b0) : sout);
    assign logical_drive[0] = (ctrl_duplex == HALF_DUPLEX ? (hd_tx_rx ? 1 : 0) : scs);

    assign logical_val[2] = sclk;
    assign logical_val[3] = !scs;

    assign logical_drive[1] = 0;
    assign logical_drive[2] = 1;
    assign logical_drive[3] = 1;

    // Set unused outputs low
    assign logical_val[1] = 0;
    assign logical_val[IO_LOGICAL - 1:4] = 0;
    assign logical_drive[IO_LOGICAL - 1:4] = 0;

    assign dout = next_from_master;

    assign start = (scs == 1'b1) && (scs_prev == 1'b0);
    assign stop = (scs == 1'b0) && (scs_prev == 1'b1);

    spi_master #(
        .DATA_BUS_WIDTH(32)
    ) spi_master (
        clk,
        rst,
        sout,
        sin,
        sclk,
        scs,
        ctrl_clk_mode,
        ctrl_bit_order,
        ctrl_sym_size,
        dout,
        din,
        start_request,
        next,
        clk_divisor,
        start_delay_us,
        sym_delay_ticks,
        num_of_symbols,
        df_mode,
        hd_tx_rx
    );

    always @(posedge clk) begin
        scs_prev <= scs;
        if (rst) begin
            starts <= 0;
            stops <= 0;
            transfers <= 0;
            start_sclk <= 0;
            start_sin <= 0;
            stop_sclk <= 0;
            stop_sin <= 0;
            to_master[0] <= 0;
            to_master[1] <= 0;
            to_master[2] <= 0;
            to_master[3] <= 0;
            next_from_master <= 0;
            to_master_checksum <= 0;
        end else begin
            if (start) begin
                starts <= starts + 1;
                start_sclk <= sclk;
                start_sin <= sin;
                next_from_master <= next_from_master + 1;
            end
            if (next) begin
                transfers <= transfers + 1;

                if ((ctrl_duplex == FULL_DUPLEX) || (hd_proc_tx_rx == HD_PROC_TX)) begin
                    next_from_master <= next_from_master + 1;
                end

                if ((ctrl_duplex == FULL_DUPLEX) || (hd_proc_tx_rx == HD_PROC_RX)) begin
                    to_master_checksum <= to_master_checksum + din;

                    to_master[0] <= to_master[1];
                    to_master[1] <= to_master[2];
                    to_master[2] <= to_master[3];
                    to_master[3] <= din;
                end

                // half-duplex mode
                if (ctrl_duplex == HALF_DUPLEX) begin
                    if (hd_proc_tx_rx == HD_PROC_RX) begin
                        hd_rx_cnt <= hd_rx_cnt - 1;
                    end
                    if (hd_tx_cnt && (hd_proc_tx_rx == HD_PROC_TX)) begin
                        hd_tx_cnt <= hd_tx_cnt - 1;
                    end
                end
            end
            if (stop) begin
                stops <= stops + 1;
                stop_sclk <= sclk;
                stop_sin <= sin;
                spi_slave_ctrl[10] <= 0;
                // No more bytes are going to be sent so undo that last increment
                if (ctrl_duplex == FULL_DUPLEX) begin
                    next_from_master <= next_from_master - 1;
                end
            end

            // APB interface
            if (PSEL) begin
                if (PWRITE && PENABLE) begin
                    case (PADDR)
                       // Writeable values
                       17: next_from_master[DATA_BITS * 0+:DATA_BITS]     <= PWDATA;
                       18: next_from_master[DATA_BITS * 1+:DATA_BITS]     <= PWDATA;
                       19: next_from_master[DATA_BITS * 2+:DATA_BITS]     <= PWDATA;
                       20: next_from_master[DATA_BITS * 3+:DATA_BITS]     <= PWDATA;

                       25: spi_slave_ctrl[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       26: spi_slave_ctrl[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

                       27: hd_tx_cnt[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                       28: hd_tx_cnt[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                       29: hd_rx_cnt[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                       30: hd_rx_cnt[DATA_BITS * 1+:DATA_BITS] <= PWDATA;

                       31: clk_divisor[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       32: clk_divisor[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

                       33: num_of_symbols[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       34: num_of_symbols[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

                       35: start_delay_us  <= PWDATA;
                       36: sym_delay_ticks[DATA_BITS * 0+:DATA_BITS]  <= PWDATA;
                       37: sym_delay_ticks[DATA_BITS * 1+:DATA_BITS]  <= PWDATA;

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

                       13: PRDATA <= to_master[0][7:0];
                       14: PRDATA <= to_master[1][7:0];
                       15: PRDATA <= to_master[2][7:0];
                       16: PRDATA <= to_master[3][7:0];

                       17: PRDATA <= next_from_master[DATA_BITS * 0+:DATA_BITS];
                       18: PRDATA <= next_from_master[DATA_BITS * 1+:DATA_BITS];
                       19: PRDATA <= next_from_master[DATA_BITS * 2+:DATA_BITS];
                       20: PRDATA <= next_from_master[DATA_BITS * 3+:DATA_BITS];

                       21: PRDATA <= to_master_checksum[DATA_BITS * 0+:DATA_BITS];
                       22: PRDATA <= to_master_checksum[DATA_BITS * 1+:DATA_BITS];
                       23: PRDATA <= to_master_checksum[DATA_BITS * 2+:DATA_BITS];
                       24: PRDATA <= to_master_checksum[DATA_BITS * 3+:DATA_BITS];

                       25: PRDATA <= spi_slave_ctrl[DATA_BITS * 0+:DATA_BITS];
                       26: PRDATA <= spi_slave_ctrl[DATA_BITS * 1+:DATA_BITS];

                       27: PRDATA <= hd_tx_cnt[DATA_BITS * 0+:DATA_BITS];
                       28: PRDATA <= hd_tx_cnt[DATA_BITS * 1+:DATA_BITS];
                       29: PRDATA <= hd_rx_cnt[DATA_BITS * 0+:DATA_BITS];
                       30: PRDATA <= hd_rx_cnt[DATA_BITS * 1+:DATA_BITS];

                       31: PRDATA <= clk_divisor[DATA_BITS * 0+:DATA_BITS];
                       32: PRDATA <= clk_divisor[DATA_BITS * 1+:DATA_BITS];

                       33: PRDATA <= num_of_symbols[DATA_BITS * 0+:DATA_BITS];
                       34: PRDATA <= num_of_symbols[DATA_BITS * 1+:DATA_BITS];

                       35: PRDATA <= start_delay_us;
                       36: PRDATA <= sym_delay_ticks[DATA_BITS * 0+:DATA_BITS];
                       37: PRDATA <= sym_delay_ticks[DATA_BITS * 1+:DATA_BITS];

                       40: PRDATA <= to_master[0][DATA_BITS * 0+:DATA_BITS];
                       41: PRDATA <= to_master[0][DATA_BITS * 1+:DATA_BITS];
                       42: PRDATA <= to_master[0][DATA_BITS * 2+:DATA_BITS];
                       43: PRDATA <= to_master[0][DATA_BITS * 3+:DATA_BITS];

                       44: PRDATA <= to_master[1][DATA_BITS * 0+:DATA_BITS];
                       45: PRDATA <= to_master[1][DATA_BITS * 1+:DATA_BITS];
                       46: PRDATA <= to_master[1][DATA_BITS * 2+:DATA_BITS];
                       47: PRDATA <= to_master[1][DATA_BITS * 3+:DATA_BITS];

                       48: PRDATA <= to_master[2][DATA_BITS * 0+:DATA_BITS];
                       49: PRDATA <= to_master[2][DATA_BITS * 1+:DATA_BITS];
                       50: PRDATA <= to_master[2][DATA_BITS * 2+:DATA_BITS];
                       51: PRDATA <= to_master[2][DATA_BITS * 3+:DATA_BITS];

                       52: PRDATA <= to_master[3][DATA_BITS * 0+:DATA_BITS];
                       53: PRDATA <= to_master[3][DATA_BITS * 1+:DATA_BITS];
                       54: PRDATA <= to_master[3][DATA_BITS * 2+:DATA_BITS];
                       55: PRDATA <= to_master[3][DATA_BITS * 3+:DATA_BITS];

                       default: PRDATA <= 0;
                    endcase
                end
            end
        end
    end

endmodule
