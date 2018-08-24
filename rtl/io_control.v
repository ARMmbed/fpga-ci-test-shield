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

module io_control #(
        parameter COUNT = 1
    )
    (
        input wire clk,
        input wire rst,
        inout wire [COUNT - 1:0] pin,
        output reg [COUNT - 1:0] in,
        input wire [COUNT - 1:0] val,
        input wire [COUNT - 1:0] drive
    );

    reg [COUNT - 1:0] in_unsafe;
    reg [COUNT - 1:0] pin_reg;
    integer i;

    assign pin = pin_reg;

    always @(posedge clk) begin
        in_unsafe <= pin;
        in <= in_unsafe;
        if (rst) begin
            pin_reg <= {COUNT{1'bz}};
        end else begin
            for (i = 0; i < COUNT; i = i + 1) begin
                pin_reg[i] <= drive[i] ? val[i] : 1'bz;
            end
        end
    end

endmodule
