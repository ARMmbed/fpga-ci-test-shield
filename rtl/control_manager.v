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

module control_manager #(
        parameter SPI_COUNT = 4,
        parameter SOUT_INDEX_WIDTH = 8,
        parameter ADDR_BYTES = 1
    )
    (
        input wire clk,
        input wire rst,
        input wire [SPI_COUNT - 1:0] sclks,
        input wire [SPI_COUNT - 1:0] sins,
        output reg [SOUT_INDEX_WIDTH - 1:0] sout_index,
        output reg sout_enable,
        output reg sout,

        output wire [ADDR_BYTES * 8 - 1:0] PADDR,
        output wire PSEL,
        output wire PENABLE,
        output wire PWRITE,
        output wire [7:0] PWDATA,
        input wire [7:0] PRDATA
    );

    wire [7:0] din;
    wire [7:0] dout;
    wire start, next, stop;

    wire [SPI_COUNT - 1:0] pulses;
    wire [7:0] spi_index;
    wire spi_trigger;
    wire scs;
    wire sin, sclk;
    wire [7:0] sout_index_internal;
    wire sout_internal;
    genvar i_gen;

    wire[1:0] ctrl_clk_mode;
    wire ctrl_bit_order;
    wire ctrl_duplex;
    wire[5:0] ctrl_sym_size;
    wire[7:0] ctrl_sym_cnt;

    assign ctrl_clk_mode = 2'd0;
    assign ctrl_bit_order = 1'b0;
    assign ctrl_duplex = 1'b0;
    assign ctrl_sym_size = 5'd8;
    assign ctrl_sym_cnt = 8'd0;

    assign sin = spi_index < SPI_COUNT ? sins[spi_index] : 0;
    assign sclk = spi_index < SPI_COUNT ? sclks[spi_index] : 0;

    pulse_selector #(.PULSE_COUNT(SPI_COUNT)) pulse_selector(
        .clk(clk),
        .rst(rst),
        .pulses(pulses),
        .index(spi_index),
        .trigger(spi_trigger)
    );

    spi_cs_decoder spi_cs_decoder(
        .clk(clk),
        .rst(rst),
        .start(spi_trigger),
        .sin(sin),
        .sclk(sclk),
        .scs(scs),
        .sindex(sout_index_internal)
    );

    spi_slave spi_slave(
        .clk(clk),
        .rst(rst),
        .sout(sout_internal),
        .sin(sin),
        .sclk(sclk),
        .scs(scs),
        .mode(ctrl_clk_mode),
        .bit_order(ctrl_bit_order),
        .sym_size(ctrl_sym_size),
        .dout(dout),
        .din(din),
        .start(start),
        .next(next),
        .stop(stop)
    );

    spi_slave_to_apb2_master #(.ADDR_BYTES(ADDR_BYTES)) spi_slave_to_apb2_master(
        .clk(clk),
        .rst(rst),
        .spi_start(start),
        .spi_next(next),
        .spi_stop(stop),
        .from_spi(din),
        .to_spi(dout),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    for (i_gen = 0; i_gen < SPI_COUNT; i_gen = i_gen + 1) begin
        spi_sequence_detector spi_sequence_detector(
            .clk(clk),
            .rst(rst),
            .sin(sins[i_gen]),
            .sclk(sclks[i_gen]),
            .match(pulses[i_gen])
        );
    end

    always @(posedge clk) begin
        sout_index <= sout_index_internal;
        sout_enable <= scs;
        sout <= sout_internal;
    end

endmodule
