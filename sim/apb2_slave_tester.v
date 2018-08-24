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

// This is a utility module to test apb2 slaves
//
// This takes standard APB signals and allows
// communication to a slave via the tasks
// write and read.

module apb2_slave_tester #(
        parameter ADDR_BITS = 4,
        parameter DATA_BITS = 8
    )
    (
        input wire PCLK,
        output reg [ADDR_BITS - 1:0] PADDR,
        output reg PSEL,
        output reg PENABLE,
        output reg PWRITE,
        output reg [DATA_BITS - 1:0] PWDATA,
        input wire [DATA_BITS - 1:0] PRDATA
    );

    initial begin
        PADDR = 'hx;
        PSEL = 0;
        PENABLE = 'hx;
        PWRITE = 'hx;
        PWDATA = 'hx;
    end

    task write;
        input reg [ADDR_BITS - 1:0] addr;
        input reg [DATA_BITS - 1:0] data;
        begin
            // Setup phase
            @(negedge PCLK);
            PADDR = addr;
            PSEL = 1;
            PWRITE = 1;
            PENABLE = 0;
            PWDATA = data;

            // Access phase
            @(negedge PCLK);
            PENABLE = 1;

            // Idle
            @(negedge PCLK);
            PADDR = 'hx;
            PSEL = 0;
            PWRITE = 'hx;
            PENABLE = 'hx;
            PWDATA = 'hx;
        end
    endtask

    task write2le;
        input reg [ADDR_BITS - 1:0] addr;
        input reg [DATA_BITS * 2 - 1:0] data;
        begin
            write(addr + 0, data[DATA_BITS * 0+:DATA_BITS]);
            write(addr + 1, data[DATA_BITS * 1+:DATA_BITS]);
        end
    endtask

    task write4le;
        input reg [ADDR_BITS - 1:0] addr;
        input reg [DATA_BITS * 4 - 1:0] data;
        begin
            write(addr + 0, data[DATA_BITS * 0+:DATA_BITS]);
            write(addr + 1, data[DATA_BITS * 1+:DATA_BITS]);
            write(addr + 2, data[DATA_BITS * 2+:DATA_BITS]);
            write(addr + 3, data[DATA_BITS * 3+:DATA_BITS]);
        end
    endtask

    task read;
        input reg [ADDR_BITS - 1:0] addr;
        output reg [DATA_BITS - 1:0] data;
        begin
            // Setup phase
            @(negedge PCLK);
            PADDR = addr;
            PSEL = 1;
            PWRITE = 0;
            PENABLE = 0;

            // Access phase
            @(negedge PCLK);
            PENABLE = 1;
            data = PRDATA;

            // Idle
            @(negedge PCLK);
            PADDR = 'hx;
            PSEL = 0;
            PWRITE = 'hx;
            PENABLE = 'hx;
        end
    endtask

    task read2le;
        input reg [ADDR_BITS - 1:0] addr;
        output reg [DATA_BITS * 2 - 1:0] data;
        begin
            read(addr + 0, data[DATA_BITS * 0+:DATA_BITS]);
            read(addr + 1, data[DATA_BITS * 1+:DATA_BITS]);
        end
    endtask

    task read4le;
        input reg [ADDR_BITS - 1:0] addr;
        output reg [DATA_BITS * 4 - 1:0] data;
        begin
            read(addr + 0, data[DATA_BITS * 0+:DATA_BITS]);
            read(addr + 1, data[DATA_BITS * 1+:DATA_BITS]);
            read(addr + 2, data[DATA_BITS * 2+:DATA_BITS]);
            read(addr + 3, data[DATA_BITS * 3+:DATA_BITS]);
        end
    endtask

endmodule
