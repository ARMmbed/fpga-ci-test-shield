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

// Decoder for mode 0 SPI
// Format
//      64 bits = Key used for match detection
//
// Guarantees
//      -match on same cycle as falling edge of sclk
//      -match asserted for one clock cycle

module spi_sequence_detector #(
        parameter KEY = 64'h929d9a9b2935a265,
        parameter KEY_SIZE = 64
    )
    (
        input wire clk,
        input wire rst,
        input wire sin,
        input wire sclk,
        output wire match
    );

    reg [KEY_SIZE - 1 - 1:0] bitstream;
    reg sclk_prev;
    reg match_reg;
    wire [KEY_SIZE - 1:0] key;
    wire posedge_sclk, negedge_sclk;

    assign key = {bitstream, sin};
    assign posedge_sclk = (sclk == 1) && (sclk_prev == 0);
    assign negedge_sclk =  (sclk == 0) && (sclk_prev == 1);
    assign match = negedge_sclk && match_reg;

    always @(posedge clk) begin
        if (rst) begin
            bitstream <= 0;
            sclk_prev <= 0;
            match_reg <= 0;
        end else begin
            sclk_prev <= sclk;

            if (posedge_sclk) begin
                bitstream <= (bitstream << 1) | sin;
                match_reg <= key == KEY;
            end else if (negedge_sclk) begin
                match_reg <= 0;
            end
        end
    end
endmodule
