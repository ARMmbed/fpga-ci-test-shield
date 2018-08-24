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

// The frequency of the clock_out = The frequency of the clk divided by divisor
//
// clk - base clock
// rst - reset line
// clock_out - output clock
// divisor - base clock divisor
// clk_polarity - clock polarity (0 - iddle state low, 1- idle state high)
// sym_delay_request - request delay between symbols
// sym_delay_ticks - delay between symbols in FPGA ticks (1 tick == 10 ns)
//
// example: Base clock = 100MHz
//          output clock 1 MHz: divisor = 100
module clock_divider
     (
        input wire clk,
        input wire rst,
        output wire clock_out,
        input wire [15:0] divisor,
        input wire clk_polarity,
        input wire sym_delay_request,
        input wire [15:0] sym_delay_ticks
    );
    reg [15:0] counter;
    reg [15:0] delay;
    reg [15:0] divisor_reg;
    reg start_reg;
    reg sym_delay_request_reg;

    assign clock_out = start_reg ? ((counter < (divisor_reg / 2)) ? (clk_polarity ? 1'b0 : 1'b1) : (clk_polarity ? 1'b1 : 1'b0)) : clk_polarity;

    always @(posedge clk) begin
        if (!rst) begin
            if (sym_delay_request) begin
                sym_delay_request_reg <= 1;
            end
            if (delay == 0) begin
                start_reg <= 1;
                if (start_reg) counter <= counter + 16'd1;
                if (counter >= (divisor_reg - 1)) begin
                    counter <= 16'd0;
                    if (sym_delay_request_reg) begin
                        delay <= sym_delay_ticks; // delay between symbols
                        sym_delay_request_reg <= 0;
                        start_reg <= 0;
                    end
                end
            end else begin
                delay <= delay - 1;
            end
        end else begin
            counter <= 0;
            divisor_reg <= divisor;
            delay <= ((divisor / 2) - 1); // 1 spi clock period between cs and first sclk edge
            start_reg <= 0;
            sym_delay_request_reg <= 0;
        end
    end

endmodule
