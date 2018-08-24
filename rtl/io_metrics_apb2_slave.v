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

// IO metrics module
//
// This modules records metrics on every IO pin. By default it
// is inactive and must be enabled by writing the 'active' bit to
// 1. Additionally recorded metrics can be reset by setting the
// write only reset bit to 1.
//
// APB interface:
// Addr             Size    Name                                    Type
//
//
// +0               4       control
//                              bit 0 - active                      RW
//                              bit 1 - reset                       WO
//                              bit 2 - 31 - reserved
// +4 to 63                 reserved
//
// +64              4       min_pulse_low[1]                        RO
// +68              4       min_pulse_high[1]                       RO
// +72              4       max_pulse_low[1]                        RO
// +76              4       max_pulse_high[1]                       RO
// +80              4       rising_edges[1]                         RO
// +84              4       falling_edges[1]                        RO
// +88 to 127               reserved[1]
//
// +128             4       min_pulse_low[1]                        RO
// +132             4       min_pulse_high[1]                       RO
// +136             4       max_pulse_low[1]                        RO
// +140             4       max_pulse_high[1]                       RO
// +144             4       rising_edges[1]                         RO
// +148             4       falling_edges[1]                        RO
// +152 to 191              reserved[1]
//
// +(N + 1)*64+0    4       min_pulse_low[N]                        RO
// +(N + 1)*64+4    4       min_pulse_high[N]                       RO
// +(N + 1)*64+8    4       max_pulse_low[N]                        RO
// +(N + 1)*64+12   4       max_pulse_high[N]                       RO
// +(N + 1)*64+16   4       rising_edges[N]                         RO
// +(N + 1)*64+20   4       falling_edges[N]                        RO
// +(N + 1)*64+24 to 127  reserved[N]
//

module io_metrics_apb2_slave #(
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

    reg active;
    reg local_reset;
    reg [31:0] min_pulse_low[0:IO_LOGICAL - 1];
    reg [31:0] min_pulse_high[0:IO_LOGICAL - 1];
    reg [31:0] max_pulse_low[0:IO_LOGICAL - 1];
    reg [31:0] max_pulse_high[0:IO_LOGICAL - 1];
    reg [31:0] rising_edges[0:IO_LOGICAL - 1];
    reg [31:0] falling_edges[0:IO_LOGICAL - 1];

    reg [31:0] cur_pulse_low[0:IO_LOGICAL - 1];
    reg [31:0] cur_pulse_high[0:IO_LOGICAL - 1];
    reg rising_since_active[0:IO_LOGICAL - 1];
    reg falling_since_active[0:IO_LOGICAL - 1];

    reg [IO_LOGICAL - 1:0] prev_logical_in;

    integer i;

    wire [6:0] addr_bank;
    wire [4:0] addr_word;
    wire [2:0] addr_byte;

    assign addr_bank = PADDR[ADDR_BITS - 1:6];
    assign addr_word = PADDR[5:2];
    assign addr_byte = PADDR[1:0];

    // Set all outputs to high-z
    assign logical_val = 0;
    assign logical_drive = 0;

    always @(posedge clk) begin
        if (rst || local_reset) begin
            active <= 0;
            local_reset <= 0;
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                min_pulse_low[i] <= 32'hffffffff;
                min_pulse_high[i] <= 32'hffffffff;
                max_pulse_low[i] <= 0;
                max_pulse_high[i] <= 0;
                rising_edges[i] <= 0;
                falling_edges[i] <= 0;

                cur_pulse_low[i] <= 0;
                cur_pulse_high[i] <= 0;
                rising_since_active[i] <= 0;
                falling_since_active[i] <= 0;
            end
            prev_logical_in <= logical_in;
        end else begin
            if (active) begin
                for (i = 0; i < IO_LOGICAL; i = i + 1) begin

                    // rising edge
                    if ((prev_logical_in[i] == 0) && (logical_in[i] == 1)) begin
                        rising_edges[i] <= rising_edges[i] + 1;
                        rising_since_active[i] <= 1;
                        if (falling_since_active[i] && (cur_pulse_low[i] < min_pulse_low[i])) begin
                            min_pulse_low[i] <= cur_pulse_low[i];
                        end
                    end

                    // falling edge
                    if ((prev_logical_in[i] == 1) && (logical_in[i] == 0)) begin
                        falling_edges[i] <= falling_edges[i] + 1;
                        falling_since_active[i] <= 1;
                        if (rising_since_active[i] && (cur_pulse_high[i] < min_pulse_high[i])) begin
                            min_pulse_high[i] <= cur_pulse_high[i];
                        end
                    end

                    // low
                    if (logical_in[i] == 0) begin
                        cur_pulse_low[i] <= cur_pulse_low[i] + 1;
                        cur_pulse_high[i] <= 0;
                    end
                    if (cur_pulse_low[i] > max_pulse_low[i]) begin
                        max_pulse_low[i] <= cur_pulse_low[i];
                    end

                    // high
                    if (logical_in[i] == 1) begin
                        cur_pulse_low[i] <= 0;
                        cur_pulse_high[i] <= cur_pulse_high[i] + 1;
                    end
                    if (cur_pulse_high[i] > max_pulse_high[i]) begin
                        max_pulse_high[i] <= cur_pulse_high[i];
                    end
                end
            end else begin
                for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                    rising_since_active[i] <= 0;
                    falling_since_active[i] <= 0;
                end
            end
            prev_logical_in <= logical_in;

            // APB interface
            if (PSEL) begin
                if (PWRITE && PENABLE) begin
                    // Writeable values
                    case (PADDR)

                        0: {local_reset, active} <= PWDATA[1:0];
                        default:;
                    endcase
                end
                if (!PWRITE) begin
                    // Readable values
                    if (addr_bank == 0) begin
                        PRDATA <= (PADDR == 0) ? active : 0;
                    end else if (addr_bank < IO_LOGICAL + 1) begin
                        case ({addr_word, 2'b00})
                             0: PRDATA <= min_pulse_low[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                             4: PRDATA <= min_pulse_high[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                             8: PRDATA <= max_pulse_low[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                            12: PRDATA <= max_pulse_high[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                            16: PRDATA <= rising_edges[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                            20: PRDATA <= falling_edges[addr_bank - 1][addr_byte * DATA_BITS+:DATA_BITS];
                            default: PRDATA <= 0;
                        endcase
                    end else begin
                        PRDATA <= 0;
                    end
                end
            end
        end
    end

endmodule
