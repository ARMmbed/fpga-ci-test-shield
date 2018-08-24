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

module mbed_tester_shield_top(
        input wire clk,
        inout wire [127:0] IO,
        inout wire RESET_BTN,
        inout wire REPROGRAM,
        inout wire [2:0] DIG_ID,
        inout wire [2:0] LED,
        inout wire [3:0] SPI_IO,
        inout wire SPI_CS,
        inout wire I2C_RESET,
        inout wire [2:0] I2C_SDA,
        inout wire [2:0] I2C_SCL,
        inout wire AN_MUX_ENABLE,
        inout wire AN_MUX_PWMOUT,
        input wire AN_MUX_ANALOGINP,
        input wire AN_MUX_ANALOGINN,
        inout wire [7:0] AN_MUX_ADDR,
        input wire [3:0] ANINP,
        input wire [3:0] ANINN
    );

    localparam IO_PHYSICAL = 128;
    localparam I2C_COUNT = 3;
    localparam AN_MUX_WIDTH = 8;
    localparam LED_COUNT = 4;
    localparam DIGITAL_ID_COUNT = 3;
    localparam ANALOG_COUNT = 4;
    // XADC channels to activate:
    // ANIN0:            AD0P_15
    // ANIN1:            AD0N_15
    // ANIN4:            AD1P_15
    // ANIN5:            AD1N_15
    // ANIN6:            AD9P_15
    // ANIN7:            AD9N_15
    // ANIN8:            AD2P_15
    // ANIN9:            AD2N_15
    // AN_MUX_ANALOGINP: AD4P_35
    // GND (AN_MUX_ANALOGINN): AD4N_35
    localparam XADC_CHANNEL_SELECTION_MASK = 16'h0217;

    // Reset everything on boot
    reg [3:0] initial_reset_count = 15;
    always @(posedge clk) begin
        if (initial_reset_count > 0) begin
            initial_reset_count <= initial_reset_count - 1;
        end
    end

    wire rst;
    wire reset_req;
    wire reprogram_req;

    assign rst = reset_req || (initial_reset_count > 0);

    // STARTUPE2 primitive is to to provide access to the serial flash SPI clock (CCLK).
    // The first 3 cycles after programming CCLK aren't output. As a workaround for this
    // clock out 3 dummy cycles while the pin in high-z on boot while the system is held in
    // reset. For more information about the 3 cycle requirent on CCLK see the STARTUPE2 section
    // in the Artix-7 User Guide - UG470
    //
    // This logic also ensures that inputs to USRCCLKO and USRCCLKTS are properly flopped
    reg spi_clk_val_reg = 1;
    reg spi_clk_ndrive_reg = 1;
    always @(posedge clk) begin
        if (rst) begin
            spi_clk_val_reg <= !spi_clk_val_reg;
            spi_clk_ndrive_reg <= 1;
        end else begin
            spi_clk_val_reg <= spi_clk_val;
            spi_clk_ndrive_reg <= !spi_clk_drive;
        end
    end
    STARTUPE2 #(.PROG_USR("FALSE"), .SIM_CCLK_FREQ(10.0)) STARTUPE2 (
        .CFGCLK     (),
        .CFGMCLK    (),
        .EOS        (),
        .PREQ       (),
        .CLK        (1'b0),
        .GSR        (1'b0),
        .GTS        (1'b0),
        .KEYCLEARB  (1'b0),
        .PACK       (1'b0),
        .USRCCLKO   (spi_clk_val_reg),      // CCLK value
        .USRCCLKTS  (spi_clk_ndrive_reg),   // CCLK drive enable, active low
        .USRDONEO   (1'b1),
        .USRDONETS  (1'b1)
    );

    reprogram_controller reprogram_controller(
        .clk(clk),
        .reprogram(reprogram_req),
        .address(32'h0)
    );

    wire [IO_PHYSICAL - 1:0] io_in;
    wire [IO_PHYSICAL - 1:0] io_val;
    wire [IO_PHYSICAL - 1:0] io_drive;
    io_control #(.COUNT(IO_PHYSICAL)) io_control (
        .clk(clk),
        .rst(rst),
        .pin(IO),
        .in(io_in),
        .val(io_val),
        .drive(io_drive)
    );

    wire reset_btn_in;
    wire reset_btn_val;
    wire reset_btn_drive;
    io_control #(.COUNT(1)) io_control_reset_btn(
        .clk(clk),
        .rst(rst),
        .pin(RESET_BTN),
        .in(reset_btn_in),
        .val(reset_btn_val),
        .drive(reset_btn_drive)
    );

    wire reprogram_in;
    wire reprogram_val;
    wire reprogram_drive;
    io_control #(.COUNT(1)) io_control_reprogram(
        .clk(clk),
        .rst(rst),
        .pin(REPROGRAM),
        .in(reprogram_in),
        .val(reprogram_val),
        .drive(reprogram_drive)
    );

    wire [DIGITAL_ID_COUNT - 1:0] digital_id_in;
    wire [DIGITAL_ID_COUNT - 1:0] digital_id_val;
    wire [DIGITAL_ID_COUNT - 1:0] digital_id_drive;
    io_control #(.COUNT(DIGITAL_ID_COUNT)) io_control_digital_id(
        .clk(clk),
        .rst(rst),
        .pin(DIG_ID),
        .in(digital_id_in),
        .val(digital_id_val),
        .drive(digital_id_drive)
    );

    wire [LED_COUNT - 1:0] leds_in;
    wire [LED_COUNT - 1:0] leds_val;
    wire [LED_COUNT - 1:0] leds_drive;
    // LED 0 is a stub for backwards compatiblity
    assign leds_in[0] = leds_val[0] & leds_drive[0];
    io_control #(.COUNT(LED_COUNT - 1)) io_control_leds(
        .clk(clk),
        .rst(rst),
        .pin(LED),
        .in(leds_in[LED_COUNT - 1:1]),
        .val(leds_val[LED_COUNT - 1:1]),
        .drive(leds_drive[LED_COUNT - 1:1])
    );

    wire [3:0] spi_io_in;
    wire [3:0] spi_io_val;
    wire [3:0] spi_io_drive;
    io_control #(.COUNT(4)) io_control_spi_io(
        .clk(clk),
        .rst(rst),
        .pin(SPI_IO),
        .in(spi_io_in),
        .val(spi_io_val),
        .drive(spi_io_drive)
    );

    // spi_clk taken from STARTUPE2
    wire spi_clk_in;
    wire spi_clk_val;
    wire spi_clk_drive;
    assign spi_clk_in = 0;

    wire spi_cs_in;
    wire spi_cs_val;
    wire spi_cs_drive;
    io_control #(.COUNT(1)) io_control_spi_cs(
        .clk(clk),
        .rst(rst),
        .pin(SPI_CS),
        .in(spi_cs_in),
        .val(spi_cs_val),
        .drive(spi_cs_drive)
    );

    wire i2c_reset_in;
    wire i2c_reset_val;
    wire i2c_reset_drive;
    io_control #(.COUNT(1)) io_control_i2c_reset(
        .clk(clk),
        .rst(rst),
        .pin(I2C_RESET),
        .in(i2c_reset_in),
        .val(i2c_reset_val),
        .drive(i2c_reset_drive)
    );

    wire [I2C_COUNT - 1:0] i2c_sda_in;
    wire [I2C_COUNT - 1:0] i2c_sda_val;
    wire [I2C_COUNT - 1:0] i2c_sda_drive;
    io_control #(.COUNT(I2C_COUNT)) io_control_i2c_sda(
        .clk(clk),
        .rst(rst),
        .pin(I2C_SDA),
        .in(i2c_sda_in),
        .val(i2c_sda_val),
        .drive(i2c_sda_drive)
    );

    wire [I2C_COUNT - 1:0] i2c_scl_in;
    wire [I2C_COUNT - 1:0] i2c_scl_val;
    wire [I2C_COUNT - 1:0] i2c_scl_drive;
    io_control #(.COUNT(I2C_COUNT)) io_control_i2c_scl(
        .clk(clk),
        .rst(rst),
        .pin(I2C_SCL),
        .in(i2c_scl_in),
        .val(i2c_scl_val),
        .drive(i2c_scl_drive)
    );

    wire an_mux_enable_in;
    wire an_mux_enable_val;
    wire an_mux_enable_drive;
    io_control #(.COUNT(1)) io_control_an_mux_enable(
        .clk(clk),
        .rst(rst),
        .pin(AN_MUX_ENABLE),
        .in(an_mux_enable_in),
        .val(an_mux_enable_val),
        .drive(an_mux_enable_drive)
    );

    wire an_mux_pwmout_in;
    wire an_mux_pwmout_val;
    wire an_mux_pwmout_drive;
    io_control #(.COUNT(1)) io_control_an_mux_pwmout(
        .clk(clk),
        .rst(rst),
        .pin(AN_MUX_PWMOUT),
        .in(an_mux_pwmout_in),
        .val(an_mux_pwmout_val),
        .drive(an_mux_pwmout_drive)
    );

    wire an_mux_analogin_in;
    wire an_mux_analogin_val;
    wire an_mux_analogin_drive;
    io_control #(.COUNT(1)) io_control_an_mux_analogin(
        .clk(clk),
        .rst(rst),
        .pin(),
        .in(an_mux_analogin_in),
        .val(an_mux_analogin_val),
        .drive(an_mux_analogin_drive)
    );

    wire [AN_MUX_WIDTH - 1:0] an_mux_addr_in;
    wire [AN_MUX_WIDTH - 1:0] an_mux_addr_val;
    wire [AN_MUX_WIDTH - 1:0] an_mux_addr_drive;
    io_control #(.COUNT(AN_MUX_WIDTH)) io_control_an_mux_addr(
        .clk(clk),
        .rst(rst),
        .pin(AN_MUX_ADDR),
        .in(an_mux_addr_in),
        .val(an_mux_addr_val),
        .drive(an_mux_addr_drive)
    );

    wire [ANALOG_COUNT - 1:0] aninp_in;
    wire [ANALOG_COUNT - 1:0] aninp_val;
    wire [ANALOG_COUNT - 1:0] aninp_drive;
    io_control #(.COUNT(4)) io_control_aninp(
        .clk(clk),
        .rst(rst),
        .pin(),
        .in(aninp_in),
        .val(aninp_val),
        .drive(aninp_drive)
    );

    wire [ANALOG_COUNT - 1:0] aninn_in;
    wire [ANALOG_COUNT - 1:0] aninn_val;
    wire [ANALOG_COUNT - 1:0] aninn_drive;
    io_control #(.COUNT(4)) io_control_aninn(
        .clk(clk),
        .rst(rst),
        .pin(),
        .in(aninn_in),
        .val(aninn_val),
        .drive(aninn_drive)
    );

    wire [11:0] an_mux_analogin_measurement;
    wire [(ANALOG_COUNT * 12) - 1:0] anin_measurements;
    wire an_mux_analogin_updated;
    wire [ANALOG_COUNT - 1:0] anin_updated;
    wire sample_adc;
    adc #(.XADC_CHANNEL_SELECTION_MASK(XADC_CHANNEL_SELECTION_MASK)) adc(
        .clk(clk),
        .rst(rst),
        .vauxp({6'b000000,ANINP[2],4'b0000,AN_MUX_ANALOGINP,1'b0,ANINP[3],ANINP[1],ANINP[0]}),
        .vauxn({6'b000000,ANINN[2],4'b0000,AN_MUX_ANALOGINN,1'b0,ANINN[3],ANINN[1],ANINN[0]}),
        .analog_measurements_reg({anin_measurements[35:24],an_mux_analogin_measurement,anin_measurements[47:36],anin_measurements[23:12],anin_measurements[11:0]}),
        .updated_reg({anin_updated[2],an_mux_analogin_updated,anin_updated[3],anin_updated[1],anin_updated[0]}),
        .sample_adc(sample_adc)
    );

    mbed_tester #(
        .IO_PHYSICAL(IO_PHYSICAL),
        .I2C_COUNT(I2C_COUNT),
        .AN_MUX_WIDTH(AN_MUX_WIDTH),
        .LED_COUNT(LED_COUNT),
        .DIGITAL_ID_COUNT(DIGITAL_ID_COUNT),
        .ANALOG_COUNT(ANALOG_COUNT)
    ) mbed_tester (
        .clk(clk),
        .rst(rst),
        .reset_req(reset_req),
        .reprogram_req(reprogram_req),

        .io_in(io_in),
        .io_val(io_val),
        .io_drive(io_drive),

        .reset_btn_in(reset_btn_in),
        .reset_btn_val(reset_btn_val),
        .reset_btn_drive(reset_btn_drive),
        .reprogram_in(reprogram_in),
        .reprogram_val(reprogram_val),
        .reprogram_drive(reprogram_drive),
        .digital_id_in(digital_id_in),
        .digital_id_val(digital_id_val),
        .digital_id_drive(digital_id_drive),
        .leds_in(leds_in),
        .leds_val(leds_val),
        .leds_drive(leds_drive),

        .spi_io_in(spi_io_in),
        .spi_io_val(spi_io_val),
        .spi_io_drive(spi_io_drive),
        .spi_clk_in(spi_clk_in),
        .spi_clk_val(spi_clk_val),
        .spi_clk_drive(spi_clk_drive),
        .spi_cs_in(spi_cs_in),
        .spi_cs_val(spi_cs_val),
        .spi_cs_drive(spi_cs_drive),

        .i2c_reset_in(i2c_reset_in),
        .i2c_reset_val(i2c_reset_val),
        .i2c_reset_drive(i2c_reset_drive),
        .i2c_sda_in(i2c_sda_in),
        .i2c_sda_val(i2c_sda_val),
        .i2c_sda_drive(i2c_sda_drive),
        .i2c_scl_in(i2c_scl_in),
        .i2c_scl_val(i2c_scl_val),
        .i2c_scl_drive(i2c_scl_drive),

        .an_mux_enable_in(an_mux_enable_in),
        .an_mux_enable_val(an_mux_enable_val),
        .an_mux_enable_drive(an_mux_enable_drive),
        .an_mux_pwmout_in(an_mux_pwmout_in),
        .an_mux_pwmout_val(an_mux_pwmout_val),
        .an_mux_pwmout_drive(an_mux_pwmout_drive),
        .an_mux_analogin_in(an_mux_analogin_in),
        .an_mux_analogin_val(an_mux_analogin_val),
        .an_mux_analogin_drive(an_mux_analogin_drive),
        .an_mux_addr_in(an_mux_addr_in),
        .an_mux_addr_val(an_mux_addr_val),
        .an_mux_addr_drive(an_mux_addr_drive),

        .aninp_in(aninp_in),
        .aninp_val(aninp_val),
        .aninp_drive(aninp_drive),
        .aninn_in(aninn_in),
        .aninn_val(aninn_val),
        .aninn_drive(aninn_drive),

        .an_mux_analogin_measurement_in(an_mux_analogin_measurement),
        .anin_measurements_in(anin_measurements),
        .an_mux_analogin_updated(an_mux_analogin_updated),
        .anin_updated(anin_updated),
        .sample_adc(sample_adc)
    );

endmodule
