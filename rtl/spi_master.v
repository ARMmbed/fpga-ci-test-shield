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

// SPI master module
//
// This modules acts as a SPI master.
//
// sout - SPI master out slave in line
// sin - SPI master in slave out line
// sclk - SPI clock line
// scs - SPI chip select
// mode - SPI mode (clock polarity/phase)
// bit_order - bit order during transmission (0 - MSB first, 1 - LSB first)
// sym_size - symbol size (1 - 32 bits)
// dout - value to write to the slave
// din - value read from the slave
// start - control signal indicating a transfer is started.
// next - control signal indicating that a symbol has been sent/received
// stop - control signal indicating the transfer has finished
// divisor - clock divider
// delay_us - delay between start request and CS assertion in us
// sym_delay_ticks - delay between symbols transmission in FPGA ticks 1 tick = 10 ns
// hd_mode - Half-Dupex mode (0 - Full-Duplex, 1 - Half-Duplex)
// hd_tx_rx_proc - in Half-Duplex mode specifies data line direction (0 - RX, 1 - TX)
//
// Guarantees
// -control signals are pulsed for one cycle

module spi_master #(
        parameter DATA_BUS_WIDTH = 8
    )
    (
        input wire clk,
        input wire rst,
        output reg sout,
        input wire sin,
        output wire sclk,
        output reg scs,
        input wire [1:0] mode,
        input wire bit_order,
        input wire [5:0] sym_size,
        input wire [DATA_BUS_WIDTH - 1:0] dout,
        output reg [DATA_BUS_WIDTH - 1:0] din,
        input wire start,
        output reg next,
        input wire [15:0] divisor,
        input wire [7:0] delay_us,
        input wire [15:0] sym_delay_ticks,
        input wire [15:0] num_of_symbols,
        input wire hd_mode,
        output wire hd_tx_rx_proc
    );

    localparam SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE   = 2'b00;
    localparam SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE  = 2'b01;
    localparam SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE  = 2'b10;
    localparam SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE = 2'b11;

    reg sclk_prev;
    reg [5:0] count;
    reg [DATA_BUS_WIDTH - 2:0] shift_in;
    reg [DATA_BUS_WIDTH - 1:0] shift_out;

    reg [1:0] mode_reg;
    reg [5:0] sym_size_reg;
    reg [5:0] sym_msb_idx;
    reg [DATA_BUS_WIDTH - 1:0] in_bit_mask;

    reg [15:0] delay_us_reg;
    reg [15:0] sym_delay_ticks_reg;
    reg [15:0] num_of_symbols_reg;
    reg [15:0] num_of_symbols_hf_reg;

    reg [15:0] cs_deasert_delay;
    reg cs_deasert_request;

    wire posedge_sclk;
    wire negedge_sclk;

    wire clk_polarity;

    reg sclk_start;
    reg sym_delay_request;

    // Combinational logic
    assign posedge_sclk = (sclk == 1'b1) && (sclk_prev == 1'b0);
    assign negedge_sclk = (sclk == 1'b0) && (sclk_prev == 1'b1);
    assign clk_polarity = (mode == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE || mode == SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE);
    assign hd_tx_rx_proc = (hd_mode == 1'b1 && num_of_symbols_reg > num_of_symbols_hf_reg); // 1 TX, 0 RX

    clock_divider clock_divider(clk, !(sclk_start & !cs_deasert_request), sclk, divisor, clk_polarity, sym_delay_request, sym_delay_ticks_reg);

    // Sequential logic
    always @(posedge clk) begin
        sclk_prev <= sclk;

        if (rst == 1'b1) begin
            // Reset

            sout <= 0;
            din <= 0;
            scs <= 1'b0;
            next <= 0;
            if (mode == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE ||
                mode == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE) begin
                sclk_prev <= 0;
            end else
                sclk_prev <= 1;

            count <= 0;
            shift_out <= 0;
            shift_in <= 0;
            in_bit_mask <= 1;

            mode_reg <= mode;
            sym_msb_idx <= sym_size - 1;

            delay_us_reg <= delay_us * 100;
            sclk_start <= 0;
            num_of_symbols_reg <= num_of_symbols;
            num_of_symbols_hf_reg <= (num_of_symbols / 2);
            sym_delay_ticks_reg <= sym_delay_ticks;

            cs_deasert_delay <= divisor - 2;
            cs_deasert_request <= 1'b0;

        end else if (start == 0) begin
            sclk_start <= 0;
            scs <= 1'b0;
            shift_in <= 0;
            din <= 0;
        end else begin
            if (delay_us_reg == 8'd0) begin
                sclk_start <= 1;
                scs <= 1'b1;

                if (cs_deasert_request == 1'b1) begin
                    if (cs_deasert_delay == 0) begin
                        scs <= 1'b0;
                    end else cs_deasert_delay = cs_deasert_delay - 1;
                end

                if (num_of_symbols_reg == 8'd0) begin
                    if ((mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE ||
                        mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE) && sclk == 0) begin
                            cs_deasert_request <= 1'b1;
                    end
                    if ((mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE ||
                        mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE) && sclk == 1) begin
                            cs_deasert_request <= 1'b1;
                    end
                end

                if (next) begin
                    shift_out <= dout;
                    num_of_symbols_reg <= num_of_symbols_reg - 1;
                    if (sym_delay_ticks != 0) begin
                        sym_delay_request <= 1;
                    end
                end else begin
                    sym_delay_request <= 0;
                end

                if ((mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE && posedge_sclk) ||
                    (mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE && negedge_sclk)  ||
                    (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE && negedge_sclk) ||
                    (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE && posedge_sclk)) begin
                    if (count == sym_msb_idx) begin
                        count <= 0;
                        if (hd_mode == 0 || hd_tx_rx_proc == 0) begin
                            if (bit_order == 0)
                                din <= {shift_in, sin};
                            else begin
                                if (sin == 1)
                                    din <= (shift_in | in_bit_mask);
                                else
                                    din <= shift_in;
                            end
                        end
                        shift_in <= 0;
                        in_bit_mask <= 1;
                        next <= 1;
                    end else begin
                        count <= count + 1;
                        if (hd_mode == 0 || hd_tx_rx_proc == 0) begin
                            if (bit_order == 0)
                                shift_in <= {shift_in, sin};
                            else begin
                                if (sin == 1)
                                    shift_in <= (shift_in | in_bit_mask);
                                    in_bit_mask = in_bit_mask << 1;
                            end
                        end
                        next <= 0;
                    end
                end else begin
                    next <= 0;
                end

                if (hd_mode == 0 || hd_tx_rx_proc == 1) begin
                    if (!sclk_start && (mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE ||
                                        mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE)) begin
                        if (bit_order == 0) begin
                            sout <= dout[sym_msb_idx];
                            shift_out <= dout << 1;
                        end else begin
                            sout <= dout[0];
                            shift_out <= dout >> 1;
                        end
                    end else if ((mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE && negedge_sclk) ||
                                (mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE && posedge_sclk) ||
                                (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE && posedge_sclk) ||
                                (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE && negedge_sclk)) begin
                        if (bit_order == 0) begin
                            sout <= shift_out[sym_msb_idx];
                            shift_out <= shift_out << 1;
                        end else begin
                            sout <= shift_out[0];
                            shift_out <= shift_out >> 1;
                        end
                     end
                end
            end else begin
                delay_us_reg <= delay_us_reg - 1;
                shift_out <= dout;
            end
        end
    end

endmodule
