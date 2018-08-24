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

// SPI slave module
//
// This modules acts as a SPI slave. It supports
// SPI mode 0.
//
// sout - SPI master in slave out line
// sin - SPI master out slave in line
// sclk - SPI clock line
// scs - SPI chip select
// mode - SPI mode (clock polarity/phase)
// bit_order - bit order during transmission (0 - MSB first, 1 - LSB first)
// sym_size - symbol size (1 - 32 bits)
// dout - 8 bit value to write to the master
// din - 8 bit value read from the master
// start - control signal indicating a transfer is started.
// next - control signal indicating that a byte has been sent/recieved
// stop - control signal indicating the transfer has finished
//
// Guarantees
// -control signals are pulsed for one cycle

module spi_slave #(
        parameter DATA_BUS_WIDTH = 8
    )
    (
        input wire clk,
        input wire rst,
        output reg sout,
        input wire sin,
        input wire sclk,
        input wire scs,
        input wire [1:0] mode,
        input wire bit_order,
        input wire [5:0] sym_size,
        input wire [DATA_BUS_WIDTH - 1:0] dout,
        output reg [DATA_BUS_WIDTH - 1:0] din,
        output wire start,
        output reg next,
        output wire stop
    );

    localparam SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE   = 2'b00;
    localparam SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE  = 2'b01;
    localparam SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE  = 2'b10;
    localparam SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE = 2'b11;

    reg sclk_prev;
    reg scs_prev;
    reg [5:0] count;
    reg [DATA_BUS_WIDTH - 2:0] shift_in;
    reg [DATA_BUS_WIDTH - 1:0] shift_out;

    reg [1:0] mode_reg;
    reg [5:0] sym_size_reg;
    reg [5:0] sym_msb_idx;
    reg [DATA_BUS_WIDTH - 1:0] in_bit_mask;

    wire posedge_sclk;
    wire negedge_sclk;
    wire sample;

    // Combinational logic
    assign start = (scs == 1'b1) && (scs_prev == 1'b0);
    assign stop = (scs == 1'b0) && (scs_prev == 1'b1);
    assign posedge_sclk = (sclk == 1'b1) && (sclk_prev == 1'b0);
    assign negedge_sclk = (sclk == 1'b0) && (sclk_prev == 1'b1);

    // Sequential logic
    always @(posedge clk) begin
        sclk_prev <= sclk;
        scs_prev <= scs;

        if (rst == 1'b1) begin
            // Reset

            sout <= 0;
            din <= 0;
            next <= 0;
            if (mode == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE ||
                mode == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE) begin
                sclk_prev <= 0;
            end else
                sclk_prev <= 1;
            scs_prev <= 0;

            count <= 0;
            shift_out <= 0;
            shift_in <= 0;
            in_bit_mask <= 1;

            mode_reg <= mode;
            sym_msb_idx = sym_size - 1;

        end else if (scs == 1'b0) begin
            // CS is deasserted

            count <= 0;
            shift_in <= 0;
            next <= 0;
        end else begin
            if (start || next) begin
                shift_out <= dout;
            end

            if ((mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE && posedge_sclk) ||
                (mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_SECOND_EDGE && negedge_sclk)  ||
                (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_FIRST_EDGE && negedge_sclk) ||
                (mode_reg == SPI_MODE_IDLE_HIGH_SAMPLE_SECOND_EDGE && posedge_sclk)) begin
                if (count == sym_msb_idx) begin
                    count <= 0;
                    if (bit_order == 0)
                        din <= {shift_in, sin};
                    else begin
                        if (sin == 1)
                            din <= (shift_in | in_bit_mask);
                        else
                            din <= shift_in;
                    end
                    shift_in <= 0;
                    in_bit_mask <= 1;
                    next <= 1;
                end else begin
                    count <= count + 1;
                    if (bit_order == 0)
                        shift_in <= {shift_in, sin};
                    else begin
                        if (sin == 1)
                            shift_in <= (shift_in | in_bit_mask);
                        in_bit_mask <= in_bit_mask << 1;
                    end
                    next <= 0;
                end
            end else begin
                next <= 0;
            end

            if (start && (mode_reg == SPI_MODE_IDLE_LOW_SAMPLE_FIRST_EDGE ||
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
    end

endmodule
