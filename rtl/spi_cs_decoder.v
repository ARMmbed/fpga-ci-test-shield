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

// SPI chip select decoder
//
// This module takes the first two spi transfers
// and uses the values taken from them to simulate
// a chip select and select a pin to use for slave out.
//
// After the start condition is pulsed the following values are decoded:
// first 8 bits = Pin to use for chip select or 0xFF for invalid
// second 8 bits = Byte cycles to assert chip select for
//
// This is intended for use with the spi_sequence_detector which
// detects the start of a session.
//
// Note - this is expecting SPI phase and polarity to be 0
//
// Requirements
//  -The "start" parameter must be asserted when sclk is low
//
// Guarantees
//  -Chip select asserted on same cycle as the falling edge of the
//      slave clock after select and cycles have been read
//  -Chip select deasserted on falling edge of the slave clock
//      after the requested number of cycles have passed

module spi_cs_decoder #(
        parameter SELECT_SIZE = 8,
        parameter CYCLES_SIZE = 8
    )
    (
        input wire clk,
        input wire rst,
        input wire start,
        input wire sin,
        input wire sclk,
        output wire scs,
        output reg [SELECT_SIZE - 1:0] sindex
    );

    reg [CYCLES_SIZE + 3 - 1:0] scycles;
    reg [SELECT_SIZE + CYCLES_SIZE - 1 - 1:0] bitstream;
    reg sclk_prev;
    reg started;
    reg [7:0] cycles_until_start;
    reg scs_start_on_falling, scs_stop_on_falling;
    wire running;
    wire [SELECT_SIZE - 1:0] index;
    wire [CYCLES_SIZE - 1:0] cycles;
    wire posedge_sclk, negedge_sclk;


    assign index = bitstream[CYCLES_SIZE - 1 +:SELECT_SIZE];
    assign cycles = {bitstream[0 +:CYCLES_SIZE - 1], sin}; // Lookahead
    assign scs = (started && (!scs_start_on_falling || !sclk)) || (scs_stop_on_falling && sclk);
    assign posedge_sclk =  (sclk == 1) && (sclk_prev == 0);
    assign negedge_sclk =  (sclk == 0) && (sclk_prev == 1);
    assign running = start || started;

    always @(posedge clk) begin
        if (rst || start) begin
            sindex <= ~0;
            scycles <= 0;
            bitstream <= 0;
            sclk_prev <= 0;
            started <= 0;
            cycles_until_start <= rst ? 0 : SELECT_SIZE + CYCLES_SIZE;
            scs_start_on_falling <= 0;
            scs_stop_on_falling <= 0;
        end else begin
            sclk_prev <= sclk;

            if (posedge_sclk) begin
                bitstream <= (bitstream << 1) | sin;

                if (cycles_until_start > 0) begin
                    cycles_until_start <= cycles_until_start - 1;
                end

                if (cycles_until_start == 1) begin
                    sindex <= index;
                    scycles <= cycles << 3;
                    scs_start_on_falling <= 1;
                    started <= 1;
                end

                if (started) begin
                    scycles <= scycles - 1;
                    if (scycles == 1) begin
                        scs_stop_on_falling <= 1;
                        started <= 0;
                    end
                end
            end

            if (negedge_sclk) begin
                scs_start_on_falling <= 0;
                scs_stop_on_falling <= 0;
            end
        end
    end
endmodule
