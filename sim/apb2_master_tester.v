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

module apb2_master_tester #(
        parameter ADDR_BITS = 4,
        parameter DATA_BITS = 8
    )
    (
        input wire PCLK,
        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output wire [DATA_BITS - 1:0] PRDATA
    );

    localparam integer MEM_SIZE = 1 << ADDR_BITS;

    reg [ADDR_BITS - 1:0] PADDR_prev;
    reg [DATA_BITS - 1:0] PRDATA_reg;
    reg [DATA_BITS - 1:0] mem[0:MEM_SIZE - 1];
    integer i;

    // Public variables for assertions
    integer write_count;
    integer read_count;
    reg last_transfer_write;
    reg [ADDR_BITS - 1:0] last_addr;
    reg [DATA_BITS - 1:0] last_write;

    initial begin
        PADDR_prev = 'hx;
        PRDATA_reg = 'hx;
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 'hx;
        end
        write_count = 0;
        read_count = 0;
        last_transfer_write = 'hx;
    end

    task mem_set;
        input reg [ADDR_BITS - 1:0] addr;
        input reg [DATA_BITS - 1:0] data;
        begin
            mem[addr] = data;
        end
    endtask

    task mem_get;
        input reg [ADDR_BITS - 1:0] addr;
        output reg [DATA_BITS - 1:0] data;
        begin
            data = mem[addr];
        end
    endtask

    task mem_reset;
        begin
            for (i = 0; i < MEM_SIZE; i = i + 1) begin
                mem[i] = 'hx;
            end
        end
    endtask

    // Only output valid data if all the conditions are met
    assign PRDATA = (PADDR === PADDR_prev) && PSEL && PENABLE && !PWRITE ? PRDATA_reg : 'hx;

    always @(posedge PCLK) begin
        if (PSEL) begin
            PADDR_prev <= PADDR;
            PRDATA_reg <= PWRITE ? 'hx : mem[PADDR];
            if (PWRITE) begin
                if (PENABLE) begin
                    mem[PADDR] <= PWDATA;
                    write_count <= write_count + 1;
                    last_addr <= PADDR;
                    last_write <= PWDATA;
                    last_transfer_write <= 1;
                end
            end else begin
                if (PENABLE) begin
                    read_count <= read_count + 1;
                    last_addr <= PADDR;
                    last_transfer_write <= 0;
                end
            end
        end else begin
            PADDR_prev <= 'hx;
            PRDATA_reg <= 'hx;
        end
    end

endmodule
