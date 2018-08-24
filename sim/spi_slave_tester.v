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

// This is a utility module to test api slaves
//
// This allows SPI data to be sent and received
// from tests

module spi_slave_tester(
        input wire clk,
        input wire rst,
        input wire sout,
        output wire sin,
        output wire sclk
    );

    integer period;
    reg phase;
    reg polarity;

    task send;
        input reg [7:0] to_dut;
        reg [7:0] unused;
        begin
            transfer(to_dut, unused);
        end
    endtask

    task transfer;
        input reg [7:0] to_dut;
        output reg [7:0] from_dut;
        integer data_pos;

        begin
            data_pos = 7;
            from_dut = 0;
            if (phase == 0) begin
                repeat (8) begin

                    // Write data
                    sin_nosync = to_dut[data_pos];

                    // wait
                    #(period/2);

                    // Read on the first clock edge after idle
                    sclk_nosync = !polarity;
                    from_dut[data_pos] = sout;
                    data_pos = data_pos - 1;

                    // wait
                    #(period/2);

                    // Return to idle
                    sclk_nosync = polarity;

                end
            end else begin
                repeat (8) begin

                    // Write data on the first clock edge after idle
                    sclk_nosync = !polarity;
                    sin_nosync = to_dut[data_pos];

                    // wait
                    #(period/2);

                    // Read data on the second clock edge after idle
                    sclk_nosync = polarity;
                    from_dut[data_pos] = sout;
                    data_pos = data_pos - 1;

                    // wait
                    #(period/2);

                end
            end
        end
    endtask

    reg sin_sync;
    reg sin_nosync;
    reg sclk_sync;
    reg sclk_nosync;

    assign sin = sin_sync;
    assign sclk = sclk_sync;

    initial begin
        period = 100;
        phase = 0;
        polarity = 0;
        sin_sync = 0;
        sclk_sync = 0;
        sin_nosync = 0;
        sclk_nosync = 0;
    end

    always @(posedge clk) begin
        sin_sync <= sin_nosync;
        sclk_sync <= sclk_nosync;
    end

endmodule
