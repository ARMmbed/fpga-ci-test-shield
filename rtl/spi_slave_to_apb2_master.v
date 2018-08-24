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

`define APB_SETUP 2
`define APB_ACCESS 1
`define APB_IDLE 0

`define STATE_ADDR 4
`define STATE_DIR 3
`define STATE_XFER_1 2
`define STATE_XFER_N 1
`define STATE_IDLE 0

// SPI memory interface
//
// This module is used to connect a spi slave to a memory
// device and allow values to be read and written.
//
// - SPI start
// - SPI data 0 == addr[ADDR_BYTES - 1]
// - SPI data 1 == addr[ADDR_BYTES - 2]
// - ...
// - SPI data N == addr[0]
// - SPI data N + 1 == write_not_read
// - SPI data N + 2 == data to read or write at addr + 0
// - SPI data N + 2 == data to read or write at addr + 1
//
// Guarantees
//      -from_spi is read on the same cycle spi_next is set high
//      -PADDR is set one cycle before a read or a write
module spi_slave_to_apb2_master #(
        parameter ADDR_BYTES = 1,
        parameter DATA_BUS_WIDTH = 8
    )
    (
        input wire clk,
        input wire rst,
        input wire spi_start,
        input wire spi_next,
        input wire spi_stop,
        input wire [DATA_BUS_WIDTH - 1:0] from_spi,
        output reg [DATA_BUS_WIDTH - 1:0] to_spi,

        output reg [ADDR_BYTES * 8 - 1:0] PADDR,
        output reg PSEL,
        output reg PENABLE,
        output reg PWRITE,
        output reg [7:0] PWDATA,
        input wire [7:0] PRDATA
    );

    reg [2:0] spi_state;
    reg [3:0] spi_addr_pos;
    reg [(ADDR_BYTES - 1) * 8 - 1:0] mem_addr_low;
    reg PWRITE_n_read;
    reg [1:0] mem_state;

    always @(posedge clk) begin
        if (rst) begin
            to_spi <= 0;
            PADDR <= 0;
            PSEL <= 0;
            PENABLE <= 0;
            PWRITE <= 0;
            PWDATA <= 0;
            spi_state <= `STATE_IDLE;
            spi_addr_pos <= 0;
            mem_addr_low <= 0;
            mem_state <= `APB_IDLE;
        end else begin
            if (spi_start) begin
                spi_state <= `STATE_ADDR;
                spi_addr_pos <= 0;
                to_spi <= 0;
                mem_addr_low <= 0;
            end else if (spi_next) begin
                case (spi_state)

                    `STATE_ADDR: begin
                        if (spi_addr_pos < ADDR_BYTES - 1) begin
                            mem_addr_low[spi_addr_pos * 8+:8] <= from_spi;
                            spi_addr_pos <= spi_addr_pos + 1;
                        end else begin
                            PADDR <= {from_spi, mem_addr_low};
                            PSEL <= 1;
                            PWRITE <= 0;
                            mem_state <= `APB_SETUP;
                            spi_state <= `STATE_DIR;
                        end
                    end

                    `STATE_DIR: begin
                        PWDATA <= 0;
                        if (from_spi[0]) begin
                            PWRITE <= 1;
                            to_spi <= 0;
                        end else begin
                            PADDR <= PADDR + 1;
                            PSEL <= 1;
                            PWRITE <= 0;
                            mem_state <= `APB_SETUP;
                        end
                        spi_state <= `STATE_XFER_1;
                    end

                    `STATE_XFER_1: begin
                        PADDR <= PWRITE ? PADDR : PADDR + 1;
                        PSEL <= 1;
                        PWDATA <= PWRITE ? from_spi : 0;
                        mem_state <= `APB_SETUP;
                        spi_state <= `STATE_XFER_N;
                    end

                    `STATE_XFER_N: begin
                        PADDR <= PADDR + 1;
                        PSEL <= 1;
                        PWDATA <= PWRITE ? from_spi : 0;
                        mem_state <= `APB_SETUP;
                    end

                    default:;
                endcase
            end else if (spi_stop) begin
                spi_state <= `STATE_IDLE;
            end

            if (mem_state == `APB_SETUP) begin
                mem_state <= `APB_ACCESS;
                PENABLE <= 1;
            end else if (mem_state == `APB_ACCESS) begin
                mem_state <= `APB_IDLE;
                PSEL <= 0;
                PENABLE <= 0;
                to_spi <= PWRITE ? 0 : PRDATA;
            end
        end
    end

endmodule
