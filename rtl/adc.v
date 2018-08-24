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

// Module responsible for sampling the FPGA's XADC
// Used for testing Mbed AnalogOut
// as well as for collecting power management information

// VAUXP[15:0]/VAUXN[15:0] -> daddr/channel = 0x10 to 0x1F - ug480 pg 38, Eg. setup pg 73
module adc #(
        parameter XADC_CHANNEL_SELECTION_MASK = -1//must be set from top module
    )
    (
        input wire clk,
        input wire rst,
        input wire [15:0] vauxp,//positive XADC input channels
        input wire [15:0] vauxn,//negative XADC input channels
        output reg [(XADC_NUM_CHANNELS * 12) - 1:0] analog_measurements_reg,//will contain conversion results for all active XADC channels (16 possible channels)
        output reg [XADC_NUM_CHANNELS - 1:0] updated_reg,//indicates which of the activated channels has new, ready data
        input wire sample_adc//XADC activity will only be recorded when sample_adc==1
    );

    localparam XADC_NUM_CHANNELS =
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 0)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 1)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 2)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 3)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 4)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 5)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 6)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 7)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 8)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 9)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 10)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 11)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 12)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 13)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 14)) ? 1 : 0) +
        ((XADC_CHANNEL_SELECTION_MASK & (1 << 15)) ? 1 : 0);

    wire eoc;
    wire busy;
    wire drdy;
    wire [15:0] d_out;
    wire [4:0] channel;

    reg [6:0] daddr;
    reg [6:0] daddr_reg;
    reg [(XADC_NUM_CHANNELS * 12) - 1:0] analog_measurements;
    reg [XADC_NUM_CHANNELS - 1:0] updated;//bits in this reg pulse when corresponding XADC channels have a new conversion result

    integer i;
    integer adc_index;

    always @(*) begin
        if (rst == 0) begin
            daddr = daddr_reg;
            updated = 0;
            analog_measurements = analog_measurements_reg;
            i = 0;
            adc_index = 0;
            if (eoc) begin
                daddr = {2'b00,channel};
            end
            if (drdy && sample_adc) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (XADC_CHANNEL_SELECTION_MASK[i] == 1) begin
                        if ((i == (daddr_reg - 7'h10)) && (adc_index < XADC_NUM_CHANNELS)) begin
                            analog_measurements[(12 * adc_index)+:12] = (d_out >> 4) & 16'h0FFF;
                            updated[adc_index] = 1;
                        end
                        adc_index = adc_index + 1;
                    end
                end
            end
        end else begin//rst == 1
            daddr = 0;
            updated = 0;
            analog_measurements = 0;
            i = 0;
            adc_index = 0;
        end
    end

    always @(posedge clk) begin
        daddr_reg <= daddr;
        updated_reg <= updated;
        analog_measurements_reg <= analog_measurements;
    end

    XADC #(
        .INIT_40(16'h0000), // config reg 0
        .INIT_41(16'h210F), // config reg 1 -> SEQ1: Continuous sequence mode | ALM3/2/1/0: disable alarm outputs for temperature, VCCINT , VCCAUX , and VCCBRAM | OT: disables the over-temperature signal
        .INIT_42(16'h0400), // config reg 2 -> CD2: lower frequency ADC clk = DCLK / 4
        .INIT_48(16'h0000), // Sequencer channel selection
        .INIT_49(XADC_CHANNEL_SELECTION_MASK), // Sequencer channel selection
        .INIT_4A(16'h0000), // Sequencer Average selection
        .INIT_4B(16'h0000), // Sequencer Average selection
        .INIT_4C(16'h0000), // Sequencer Bipolar selection
        .INIT_4D(16'h0000), // Sequencer Bipolar selection
        .INIT_4E(16'h0000), // Sequencer Acq time selection
        .INIT_4F(16'h0000), // Sequencer Acq time selection
        //default unused alarm trigger thresholds vvv
        .INIT_50(16'hB5ED), // Temp alarm trigger
        .INIT_51(16'h57E4), // Vccint upper alarm limit
        .INIT_52(16'hA147), // Vccaux upper alarm limit
        .INIT_53(16'hCA33), // Temp alarm OT upper
        .INIT_54(16'hA93A), // Temp alarm reset
        .INIT_55(16'h52C6), // Vccint lower alarm limit
        .INIT_56(16'h9555), // Vccaux lower alarm limit
        .INIT_57(16'hAE4E), // Temp alarm OT reset
        .INIT_58(16'h5999), // VCCBRAM upper alarm limit
        .INIT_5C(16'h5111), // VCCBRAM lower alarm limit
        .SIM_DEVICE("7SERIES"),
        .SIM_MONITOR_FILE("design.txt")
    )

    inst (
        .CONVST(0),
        .CONVSTCLK(0),
        .DADDR(daddr),//address of register containing ADC conversion results
        .DCLK(clk),
        .DEN(eoc),
        .DI(),
        .DWE(0),
        .RESET(rst),
        .VAUXN(vauxn),//negative XADC input channels
        .VAUXP(vauxp),//positive XADC input channels
        .ALM(),
        .BUSY(busy),
        .CHANNEL(channel),//XADC channel that has performed a successful conversion when eoc pulses
        .DO(d_out),
        .DRDY(drdy),//DRP register read has completed when drdy pulses
        .EOC(eoc),//pulses when a conversion has finished and stored its result in the corresponding register
        .EOS(),
        .JTAGBUSY(),
        .JTAGLOCKED(),
        .JTAGMODIFIED(),
        .OT(),
        .MUXADDR(),
        .VP(),
        .VN()
    );
endmodule

