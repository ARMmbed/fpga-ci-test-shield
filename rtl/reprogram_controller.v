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

module reprogram_controller(
        input wire clk,
        input wire reprogram,
        input wire [31:0] address
    );

    reg n_enable_ipcape2 = 1;
    reg [7:0] prog_state = 0;
    reg [31:0] to_ipcape2 = 32'hFFFFFFFF;
    reg [31:0] to_icape2_swapped;
    reg [31:0] start_address = 32'h00000000;

    always @(*) begin: swap
        integer i;
        // Bit ordering of each byte is flipped for the ICAPE2 module.
        // Information on this bit-swap can be found in the "Parallel Bus Bit Order"
        // section of the 7 Series configuration guide - UG470
        for (i = 0; i < 8; i = i + 1) begin
            to_icape2_swapped[0 * 8 + i] = to_ipcape2[0 * 8 + 7 - i];
            to_icape2_swapped[1 * 8 + i] = to_ipcape2[1 * 8 + 7 - i];
            to_icape2_swapped[2 * 8 + i] = to_ipcape2[2 * 8 + 7 - i];
            to_icape2_swapped[3 * 8 + i] = to_ipcape2[3 * 8 + 7 - i];
        end
    end

    always @(posedge clk) begin
        // Reset handling intentionally omitted since this is a
        // use once module which triggers a system wide reprogram

        if (reprogram && (prog_state == 0)) begin
            prog_state <= 1;
            start_address <= address;
        end

        if (prog_state > 0) begin
            prog_state <= prog_state + 1;
        end

        // Reprogram sequence found in UG470 in the section "IPROG Reconfiguration"
        case (prog_state)
            1: to_ipcape2 <= 32'hFFFFFFFF;
            2: to_ipcape2 <= 32'hAA995566;
            3: to_ipcape2 <= 32'h20000000;
            4: to_ipcape2 <= 32'h30020001;
            5: to_ipcape2 <= start_address;
            6: to_ipcape2 <= 32'h30008001;
            7: to_ipcape2 <= 32'h0000000F;
            8: to_ipcape2 <= 32'h20000000;
            default: to_ipcape2 <= 32'hFFFFFFFF;
        endcase

        case (prog_state)
            1: n_enable_ipcape2 <= 0;
            2: n_enable_ipcape2 <= 0;
            3: n_enable_ipcape2 <= 0;
            4: n_enable_ipcape2 <= 0;
            5: n_enable_ipcape2 <= 0;
            6: n_enable_ipcape2 <= 0;
            7: n_enable_ipcape2 <= 0;
            8: n_enable_ipcape2 <= 0;
            default: n_enable_ipcape2 <= 1;
        endcase
    end

    ICAPE2 #(
        .DEVICE_ID(32'h3651093),    // Specifies the pre-programmed Device ID value to be used for simulation
        .ICAP_WIDTH("X32"),         // Specifies the input and output data width.
        .SIM_CFG_FILE_NAME("NONE")  // Specifies the Raw Bitstream (RBT) file to be parsed by the simulation
    ) ICAPE2 (
        .O(),                       // 32-bit output: Configuration data output bus
        .CLK(clk),                  // 1-bit input: Clock Input
        .CSIB(n_enable_ipcape2),    // 1-bit input: Active-Low ICAP Enable
        .I(to_icape2_swapped),      // 32-bit input: Configuration data input bus
        .RDWRB(0)                   // 0 to write, 1 to read
    );

endmodule
