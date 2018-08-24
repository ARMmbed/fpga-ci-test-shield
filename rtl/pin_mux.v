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

module pin_mux #(
        parameter IO_PHYSICAL = 50,
        parameter IO_LOGICAL = 6
    )
    (
        input wire [IO_PHYSICAL - 1:0] physical_in,
        output reg [IO_PHYSICAL - 1:0] physical_val,
        output reg [IO_PHYSICAL - 1:0] physical_drive,
        input wire [IO_PHYSICAL * 8 - 1:0] physical_map,

        output reg [IO_LOGICAL - 1:0] logical_in,
        input wire [IO_LOGICAL - 1:0] logical_val,
        input wire [IO_LOGICAL - 1:0] logical_drive,
        input wire [IO_LOGICAL * 8 - 1:0] logical_map
    );

    integer i;
    integer j;
    integer logical_pin;
    integer physical_pin;
    always@(*)begin
        for(i = 0; i < IO_PHYSICAL; i = i + 1)begin
            logical_pin = physical_map[i * 8+:8];
            if(logical_pin >= IO_LOGICAL)begin
                physical_val[i] = 0;
                physical_drive[i] = 0;
            end else begin
                physical_val[i] = logical_val[logical_pin];
                physical_drive[i] = logical_drive[logical_pin];
            end
        end

        for(i = 0; i < IO_LOGICAL; i = i + 1)begin
            physical_pin = logical_map[i * 8 +: 8];
            if(physical_pin >= IO_PHYSICAL)begin
                logical_in[i] = 0;
            end else begin
                logical_in[i] = physical_in[physical_pin];
            end
        end
    end

endmodule
