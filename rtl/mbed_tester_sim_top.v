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

module mbed_tester_sim_top
    #(
        parameter IO_PHYSICAL = 128,
        parameter IO_LOGICAL_PER_BANK = 8,
        parameter I2C_COUNT = 3,
        parameter AN_MUX_WIDTH = 8,
        parameter LED_COUNT = 4,
        parameter DIGITAL_ID_COUNT = 3,
        parameter ANALOG_COUNT = 4
    )
    (
        input wire clk,
        input wire rst,
        output wire reprogram_req,
        inout wire [IO_PHYSICAL - 1:0] io,
        inout wire reset_btn,
        inout wire reprogram,
        inout wire [DIGITAL_ID_COUNT - 1:0] digital_id,
        inout wire [LED_COUNT - 1:0] leds,
        inout wire [3:0] spi_io,
        inout wire spi_clk,
        inout wire spi_cs,
        inout wire i2c_reset,
        inout wire [I2C_COUNT - 1:0] i2c_sda,
        inout wire [I2C_COUNT - 1:0] i2c_scl,
        inout wire an_mux_enable,
        inout wire an_mux_pwmout,
        inout wire an_mux_analogin,
        inout wire [AN_MUX_WIDTH - 1:0] an_mux_addr,
        inout wire [ANALOG_COUNT - 1:0] aninp,
        inout wire [ANALOG_COUNT - 1:0] aninn
    );

    wire reset_req;

    wire [IO_PHYSICAL - 1:0] io_in;
    wire [IO_PHYSICAL - 1:0] io_val;
    wire [IO_PHYSICAL - 1:0] io_drive;
    io_control #(.COUNT(IO_PHYSICAL)) io_control (
        .clk(clk),
        .rst(rst),
        .pin(io),
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
        .pin(reset_btn),
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
        .pin(reprogram),
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
        .pin(digital_id),
        .in(digital_id_in),
        .val(digital_id_val),
        .drive(digital_id_drive)
    );

    wire [LED_COUNT - 1:0] leds_in;
    wire [LED_COUNT - 1:0] leds_val;
    wire [LED_COUNT - 1:0] leds_drive;
    io_control #(.COUNT(LED_COUNT)) io_control_leds(
        .clk(clk),
        .rst(rst),
        .pin(leds),
        .in(leds_in),
        .val(leds_val),
        .drive(leds_drive)
    );

    wire [3:0] spi_io_in;
    wire [3:0] spi_io_val;
    wire [3:0] spi_io_drive;
    io_control #(.COUNT(4)) io_control_spi_io(
        .clk(clk),
        .rst(rst),
        .pin(spi_io),
        .in(spi_io_in),
        .val(spi_io_val),
        .drive(spi_io_drive)
    );

    wire spi_clk_in;
    wire spi_clk_val;
    wire spi_clk_drive;
    io_control #(.COUNT(1)) io_control_spi_clk(
        .clk(clk),
        .rst(rst),
        .pin(spi_clk),
        .in(spi_clk_in),
        .val(spi_clk_val),
        .drive(spi_clk_drive)
    );

    wire spi_cs_in;
    wire spi_cs_val;
    wire spi_cs_drive;
    io_control #(.COUNT(1)) io_control_spi_cs(
        .clk(clk),
        .rst(rst),
        .pin(spi_cs),
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
        .pin(i2c_reset),
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
        .pin(i2c_sda),
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
        .pin(i2c_scl),
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
        .pin(an_mux_enable),
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
        .pin(an_mux_pwmout),
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
        .pin(an_mux_analogin),
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
        .pin(an_mux_addr),
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
        .pin(aninp),
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
        .pin(aninn),
        .in(aninn_in),
        .val(aninn_val),
        .drive(aninn_drive)
    );

    //dummy adc module
    wire [11:0] an_mux_analogin_measurement;
    wire [(ANALOG_COUNT * 12) - 1:0] anin_measurements;
    wire an_mux_analogin_updated;
    wire [ANALOG_COUNT - 1:0] anin_updated;
    wire sample_adc;
    assign an_mux_analogin_measurement = 0;
    assign anin_measurements = 0;
    assign an_mux_analogin_updated = 0;
    assign anin_updated = 0;
    assign sample_adc = 0;

    mbed_tester #(
        .IO_PHYSICAL(IO_PHYSICAL),
        .IO_LOGICAL_PER_BANK(IO_LOGICAL_PER_BANK),
        .I2C_COUNT(I2C_COUNT),
        .AN_MUX_WIDTH(AN_MUX_WIDTH),
        .LED_COUNT(LED_COUNT),
        .DIGITAL_ID_COUNT(DIGITAL_ID_COUNT),
        .ANALOG_COUNT(ANALOG_COUNT)
    ) mbed_tester (
        .clk(clk),
        .rst(rst | reset_req),
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
