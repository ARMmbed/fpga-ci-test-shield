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

`include "util.v"

module mbed_tester_sim_top_tb;
    localparam ADDR_SEL_PER = 'h0010_0000;
    localparam ADDR_BASE_PER_GPIO = 'h0010_1000;
    localparam ADDR_BASE_MUX = 'h0000_1000;
    localparam IO_PHYSICAL = 32;
    localparam IO_LOGICAL = 16;

    localparam DIGITAL_ID_COUNT = 3;
    localparam LED_COUNT = 4;
    localparam I2C_COUNT = 3;
    localparam AN_MUX_WIDTH = 8;
    localparam ANALOG_COUNT = 4;

    reg clk;
    reg rst;

    // Module signals

    wire reprogram_req;

    reg [IO_PHYSICAL - 1:0] io_reg;
    reg reset_btn_reg;
    reg reprogram_reg;
    reg [DIGITAL_ID_COUNT - 1:0] digital_id_reg;
    reg [LED_COUNT - 1:0] leds_reg;
    reg [3:0] spi_io_reg;
    reg spi_clk_reg;
    reg spi_cs_reg;
    reg i2c_reset_reg;
    reg [I2C_COUNT - 1:0] i2c_sda_reg;
    reg [I2C_COUNT - 1:0] i2c_scl_reg;
    reg an_mux_enable_reg;
    reg an_mux_pwmout_reg;
    reg an_mux_analogin_reg;
    reg [AN_MUX_WIDTH - 1:0] an_mux_addr_reg;
    reg [ANALOG_COUNT - 1:0] aninp_reg;
    reg [ANALOG_COUNT - 1:0] aninn_reg;

    wire [IO_PHYSICAL - 1:0] io;
    wire reset_btn;
    wire reprogram;
    wire [DIGITAL_ID_COUNT - 1:0] digital_id;
    wire [LED_COUNT - 1:0] leds;
    wire [3:0] spi_io;
    wire spi_clk;
    wire spi_cs;
    wire i2c_reset;
    wire [I2C_COUNT - 1:0] i2c_sda;
    wire [I2C_COUNT - 1:0] i2c_scl;
    wire an_mux_enable;
    wire an_mux_pwmout;
    wire an_mux_analogin;
    wire [AN_MUX_WIDTH - 1:0] an_mux_addr;
    wire [ANALOG_COUNT - 1:0] aninp;
    wire [ANALOG_COUNT - 1:0] aninn;

    assign io = io_reg;
    assign reset_btn = reset_btn_reg;
    assign reprogram = reprogram_reg;
    assign digital_id = digital_id_reg;
    assign leds = leds_reg;
    assign spi_io = spi_io_reg;
    assign spi_clk = spi_clk_reg;
    assign spi_cs = spi_cs_reg;
    assign i2c_reset = i2c_reset_reg;
    assign i2c_sda = i2c_sda_reg;
    assign i2c_scl = i2c_scl_reg;
    assign an_mux_enable = an_mux_enable_reg;
    assign an_mux_pwmout = an_mux_pwmout_reg;
    assign an_mux_analogin = an_mux_analogin_reg;
    assign an_mux_addr = an_mux_addr_reg;
    assign aninp = aninp_reg;
    assign aninn = aninn_reg;

    mbed_tester_sim_top #(
        .IO_PHYSICAL(IO_PHYSICAL),
        .IO_LOGICAL_PER_BANK(IO_LOGICAL),
        .I2C_COUNT(I2C_COUNT),
        .AN_MUX_WIDTH(AN_MUX_WIDTH),
        .LED_COUNT(LED_COUNT),
        .DIGITAL_ID_COUNT(DIGITAL_ID_COUNT),
        .ANALOG_COUNT(ANALOG_COUNT)
    ) mbed_tester_sim_top (
        .clk(clk),
        .rst(rst),
        .reprogram_req(reprogram_req),

        .io(io),

        .reset_btn(reset_btn),
        .reprogram(reprogram),
        .digital_id(digital_id),
        .leds(leds),

        .spi_io(spi_io),
        .spi_clk(spi_clk),
        .spi_cs(spi_cs),

        .i2c_reset(i2c_reset),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),

        .an_mux_enable(an_mux_enable),
        .an_mux_pwmout(an_mux_pwmout),
        .an_mux_analogin(an_mux_analogin),
        .an_mux_addr(an_mux_addr),

        .aninp(aninp),
        .aninn(aninn)
    );

    // Mock SPI master signals

    wire sclk;
    wire sin;
    wire sout;

    integer ctrl_index_clk = IO_PHYSICAL + 1;
    integer ctrl_index_mosi = IO_PHYSICAL + 1;
    integer ctrl_index_miso = IO_PHYSICAL + 1;

    genvar i_gen;
    for (i_gen = 0; i_gen < IO_PHYSICAL; i_gen = i_gen + 1) begin
        assign io[i_gen] = i_gen == ctrl_index_clk ? sclk : 'hz;
        assign io[i_gen] = i_gen == ctrl_index_mosi ? sin : 'hz;
        assign sout = i_gen == ctrl_index_miso ? io[i_gen] : 'hz;
    end

    spi_slave_tester spi(
        .clk(clk),
        .rst(rst),
        .sout(sout),
        .sin(sin),
        .sclk(sclk)
    );

    initial begin
      $dumpfile ("top.vcd");
      $dumpvars;
    end

    always begin
        #5 clk = !clk;
    end

    initial begin
        clk = 0;
        rst = 0;
        io_reg = 'hz;
        reset_btn_reg = 1;
        reprogram_reg = 1'bz;
        digital_id_reg = {DIGITAL_ID_COUNT{1'bz}};
        leds_reg = {LED_COUNT{1'bz}};
        spi_io_reg = 4'bz;
        spi_clk_reg = 1'bz;
        spi_cs_reg = 1'bz;
        i2c_reset_reg = 1'bz;
        i2c_sda_reg = {I2C_COUNT{1'bz}};
        i2c_scl_reg = {I2C_COUNT{1'bz}};
        an_mux_enable_reg = 1'bz;
        an_mux_pwmout_reg = 1'bz;
        an_mux_analogin_reg = 1'bz;
        an_mux_addr_reg = {AN_MUX_WIDTH{1'bz}};
        aninp_reg = {ANALOG_COUNT{1'bz}};
        aninn_reg = {ANALOG_COUNT{1'bz}};
    end

    task reset;
        input integer reset_time;
        begin
            @(negedge clk);
            rst = 1;
            #(reset_time);
            @(negedge clk);
            rst = 0;
        end
    endtask

    event terminate_sim;
    initial begin
        @terminate_sim;
        #200 $finish;
    end

    task select_control;
        input integer index_clk;
        input integer index_mosi;
        input integer index_miso;
        begin
            // Set previous pins back to Hi-Z
            if (ctrl_index_clk < IO_PHYSICAL) begin
                io_reg [ctrl_index_clk] = 'hz;
            end
            if (ctrl_index_mosi < IO_PHYSICAL) begin
                io_reg [ctrl_index_mosi] = 'hz;
            end

            // Select new pins
            ctrl_index_clk = index_clk;
            ctrl_index_mosi = index_mosi;
            ctrl_index_miso = index_miso;
        end
    endtask

    task send_key;
        begin
            spi.send('h92);
            spi.send('h9d);
            spi.send('h9a);
            spi.send('h9b);
            spi.send('h29);
            spi.send('h35);
            spi.send('ha2);
            spi.send('h65);
        end
    endtask

    task start_transfer;
        input integer address;
        input reg write_n_read;
        input integer transfers;

        begin
            // Key
            spi.send('h92);
            spi.send('h9d);
            spi.send('h9a);
            spi.send('h9b);
            spi.send('h29);
            spi.send('h35);
            spi.send('ha2);
            spi.send('h65);

            // Physical information
            spi.send(ctrl_index_miso);      // miso index
            spi.send(transfers + 5);        // transfer count

            // Transfer information
            spi.send(address[8 * 0+:8]);    // addr low
            spi.send(address[8 * 1+:8]);    //
            spi.send(address[8 * 2+:8]);    //
            spi.send(address[8 * 3+:8]);    // addr high
            spi.send(write_n_read);         // direction
        end
    endtask

    task pin_map_set;
        input integer physical;
        input integer logical;
        begin
            // Map physical pin to logical pin
            start_transfer(ADDR_BASE_MUX + physical, 1, 1);
            spi.send(logical);

            // Map logical pin to physical
            start_transfer(ADDR_BASE_MUX + IO_PHYSICAL + logical, 1, 1);
            spi.send(physical);
        end
    endtask

    task sys_io_set;
        input integer index;
        input reg value;
        input reg drive;
        integer addr;
        begin
            addr = 'h00002000 + index;
            start_transfer(addr, 1, 1);
            spi.send({drive, value});
        end
    endtask

    task sys_io_get;
        input integer index;
        output reg [7:0] value;
        integer addr;
        begin
            addr = 'h00002000 + index;
            start_transfer(addr, 0, 1);
            spi.transfer(3, value);
        end
    endtask

    task normal_operation_testcase;
        reg [7:0] mapping [0:IO_LOGICAL - 1];
        reg [7:0] data;
        reg write_n_read;
        integer transfers;
        integer base;
        reg [IO_LOGICAL - 1:0] expected;
        integer i;
        begin
            expected = 'hz;
            spi.period = 200;
            reset(20);

            // Map all pins to nothing
            select_control(0, 1, 2);
            write_n_read = 1;
            transfers = IO_PHYSICAL + IO_LOGICAL;
            start_transfer(ADDR_BASE_MUX, write_n_read, transfers);
            for (i = 0; i < transfers; i = i + 1) begin
                spi.send('hFF);
            end

            // Select GPIO as the current peripheral
            write_n_read = 1;
            transfers = 1;
            start_transfer(ADDR_SEL_PER, write_n_read, transfers);
            spi.send('h1);

            for (base = 0; base < IO_PHYSICAL; base = base + IO_LOGICAL) begin
                if (base < IO_LOGICAL) begin
                    select_control(0 + IO_LOGICAL, 1 + IO_LOGICAL, 2 + IO_LOGICAL);
                end else begin
                    select_control(0, 1, 2);
                end

                // Map pins under test
                write_n_read = 1;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_MUX + base, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    mapping[i] = i;
                    spi.send(mapping[i]); // data
                end
                write_n_read = 1;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_MUX + IO_PHYSICAL, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send(base + i); // data
                end

                // Read mapping
                write_n_read = 0;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_MUX + base, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.transfer(0, data); // data
                    `util_assert_equal(mapping[i], data);
                end

                // Write gpio to 1
                write_n_read = 1;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send(3);
                    expected[i] = 1;
                    `util_assert_equal(expected, io[base+:IO_LOGICAL]);
                end

                // Write gpio to 0
                write_n_read = 1;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send(2);
                    expected[i] = 0;
                    `util_assert_equal(expected, io[base+:IO_LOGICAL]);
                end

                // Write gpio to Z (value high)
                write_n_read = 1;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send(1);
                    expected[i] = 'hz;
                    `util_assert_equal(expected, io[base+:IO_LOGICAL]);
                end

                // Write gpio to Z (vaue low)
                write_n_read = 1;
                transfers = IO_LOGICAL;
                expected = 'hz;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send(0);
                    expected[i] = 'hz;
                    `util_assert_equal(expected, io[base+:IO_LOGICAL]);
                end

                // Set pins to 0 externally and read the value
                io_reg[base+:IO_LOGICAL] = 0;
                write_n_read = 0;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.transfer(0, data);
                    `util_assert_equal(io_reg[base + i], data);
                end

                // Set pins to 1 externally and read the value
                io_reg[base+:IO_LOGICAL] = ~0;
                write_n_read = 0;
                transfers = IO_LOGICAL;
                start_transfer(ADDR_BASE_PER_GPIO, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.transfer(0, data);
                    `util_assert_equal(io_reg[base + i], data);
                end

                // Set back to Hi-Z
                io_reg[base+:IO_LOGICAL] = 'hz;

                // Map all pins to nothing
                write_n_read = 1;
                transfers = IO_PHYSICAL + IO_LOGICAL;
                start_transfer(ADDR_BASE_MUX, write_n_read, transfers);
                for (i = 0; i < transfers; i = i + 1) begin
                    spi.send('hFF);
                end
            end
        end
    endtask

    task sys_io_testcase;
        integer sys_pin;
        reg [7:0] value;
        begin
            spi.period = 200;
            reset(20);

            select_control(0, 1, 2);

            // Address of SPI clk
            sys_pin = 6 + DIGITAL_ID_COUNT + LED_COUNT;

            // Set SPI clk to 1
            sys_io_set(sys_pin, 1, 1);
            `util_assert_equal(1, spi_clk);

            // Set SPI clk to 0
            sys_io_set(sys_pin, 0, 1);
            `util_assert_equal(0, spi_clk);

            // Set SPI clk to Z
            sys_io_set(sys_pin, 0, 0);
            `util_assert_equal(1'bz, spi_clk);

            // Read while spi_clk is 0
            spi_clk_reg = 0;
            sys_io_get(sys_pin, value);
            `util_assert_equal(0, value);

            // Read while spi_clk is 1
            spi_clk_reg = 1;
            sys_io_get(sys_pin, value);
            `util_assert_equal(1, value);

            // Read while spi_clk is 0
            spi_clk_reg = 0;
            sys_io_get(sys_pin, value);
            `util_assert_equal(0, value);

            spi_clk_reg = 1'hz;
        end
    endtask

    localparam ADDR_SYS_PIN_MODE = 'h0000_2C00;
    localparam SYS_PIN_MODE_LOGICAL_BASE = (IO_LOGICAL * 2);
    localparam SYS_PIN_MODE_OFF = 0;
    localparam SYS_PIN_MODE_SPI = 1;
    localparam SYS_PIN_MODE_I2C0 = 2;
    localparam SYS_PIN_MODE_I2C1 = 3;
    localparam SYS_PIN_MODE_I2C2 = 4;
    localparam SYS_PIN_MODE_SPI_LOGICAL_MOSI = SYS_PIN_MODE_LOGICAL_BASE + 0;
    localparam SYS_PIN_MODE_SPI_LOGICAL_MISO = SYS_PIN_MODE_LOGICAL_BASE + 1;
    localparam SYS_PIN_MODE_SPI_LOGICAL_CLK = SYS_PIN_MODE_LOGICAL_BASE + 2;
    localparam SYS_PIN_MODE_SPI_LOGICAL_CS = SYS_PIN_MODE_LOGICAL_BASE + 3;
    localparam SYS_I2C_LOGICAL_SDA_IN = SYS_PIN_MODE_LOGICAL_BASE + 0;
    localparam SYS_I2C_LOGICAL_SDA_VAL = SYS_PIN_MODE_LOGICAL_BASE + 1;
    localparam SYS_I2C_LOGICAL_SCL_IN = SYS_PIN_MODE_LOGICAL_BASE + 2;
    localparam SYS_I2C_LOGICAL_SCL_VAL = SYS_PIN_MODE_LOGICAL_BASE + 3;

    task sys_pin_mode_testcase;
        integer mosi_index;
        integer miso_index;
        integer clk_index;
        integer cs_index;
        begin
            mosi_index = 4;
            miso_index = 5;
            clk_index = 6;
            cs_index = 7;
            spi.period = 200;
            reset(20);

            // Set initial physical pin values
            io_reg[mosi_index] = 0;
            io_reg[clk_index] = 0;
            io_reg[cs_index] = 0;
            spi_io_reg[1] = 0;

            # 10

            // Verify that SPI pins are high-z
            `util_assert_equal(1'hz, spi_io[0]);
            `util_assert_equal(1'hz, io[miso_index]);
            `util_assert_equal(2'hz, spi_io[3:2]);
            `util_assert_equal(1'hz, spi_clk);
            `util_assert_equal(1'hz, spi_cs);

            select_control(0, 1, 2);

            // Set pin mapping
            pin_map_set(mosi_index, SYS_PIN_MODE_SPI_LOGICAL_MOSI);
            pin_map_set(miso_index, SYS_PIN_MODE_SPI_LOGICAL_MISO);
            pin_map_set(clk_index, SYS_PIN_MODE_SPI_LOGICAL_CLK);
            pin_map_set(cs_index, SYS_PIN_MODE_SPI_LOGICAL_CS);

            // Verify that SPI pins are high-z
            `util_assert_equal(1'hz, spi_io[0]);
            `util_assert_equal(1'hz, io[miso_index]);
            `util_assert_equal(2'hz, spi_io[3:2]);
            `util_assert_equal(1'hz, spi_clk);
            `util_assert_equal(1'hz, spi_cs);

            // Enable SPI mode
            start_transfer(ADDR_SYS_PIN_MODE, 1, 1);
            spi.send(SYS_PIN_MODE_SPI);

            // Verify that SPI pins are driven from the right source
            `util_assert_equal(io_reg[mosi_index], spi_io[0]);
            `util_assert_equal(spi_io_reg[1], io[miso_index]);
            `util_assert_equal(2'b11, spi_io[3:2]);
            `util_assert_equal(io_reg[clk_index], spi_clk);
            `util_assert_equal(io_reg[cs_index], spi_cs);

            io_reg[mosi_index] = 1;
            #100
            `util_assert_equal(io_reg[mosi_index], spi_io[0]);
            `util_assert_equal(spi_io_reg[1], io[miso_index]);
            `util_assert_equal(2'b11, spi_io[3:2]);
            `util_assert_equal(io_reg[clk_index], spi_clk);
            `util_assert_equal(io_reg[cs_index], spi_cs);

            io_reg[clk_index] = 1;
            #100
            `util_assert_equal(io_reg[mosi_index], spi_io[0]);
            `util_assert_equal(spi_io_reg[1], io[miso_index]);
            `util_assert_equal(2'b11, spi_io[3:2]);
            `util_assert_equal(io_reg[clk_index], spi_clk);
            `util_assert_equal(io_reg[cs_index], spi_cs);

            io_reg[cs_index] = 1;
            #100
            `util_assert_equal(io_reg[mosi_index], spi_io[0]);
            `util_assert_equal(spi_io_reg[1], io[miso_index]);
            `util_assert_equal(2'b11, spi_io[3:2]);
            `util_assert_equal(io_reg[clk_index], spi_clk);
            `util_assert_equal(io_reg[cs_index], spi_cs);

            spi_io_reg[miso_index] = 1;
            #100
            `util_assert_equal(io_reg[mosi_index], spi_io[0]);
            `util_assert_equal(spi_io_reg[1], io[miso_index]);
            `util_assert_equal(2'b11, spi_io[3:2]);
            `util_assert_equal(io_reg[clk_index], spi_clk);
            `util_assert_equal(io_reg[cs_index], spi_cs);

            // Disable SPI mode
            start_transfer(ADDR_SYS_PIN_MODE, 1, 1);
            spi.send(SYS_PIN_MODE_OFF);

            // Verify that SPI pins are high-z
            `util_assert_equal(1'hz, spi_io[0]);
            `util_assert_equal(1'hz, io[miso_index]);
            `util_assert_equal(2'hz, spi_io[3:2]);
            `util_assert_equal(1'hz, spi_clk);
            `util_assert_equal(1'hz, spi_cs);

            spi_io_reg[1] = 1'hz;
            io_reg[mosi_index] = 4'hz;
            io_reg[clk_index] = 1'hz;
            io_reg[cs_index] = 1'hz;
        end
    endtask

    task sys_pin_mode_i2c_testcase;
        integer sda_in_index;
        integer sda_val_index;
        integer scl_in_index;
        integer scl_val_index;
        integer i;
        begin
            for (i = 0; i < 3; i = i + 1) begin
                reset(20);
                sda_in_index = 8;
                sda_val_index = 9;
                scl_in_index = 10;
                scl_val_index = 11;

                // Set initial physical pin values
                io_reg[sda_val_index] = 1;
                io_reg[scl_val_index] = 1;

                # 10

                // Verify that I2C pins are high-z
                `util_assert_equal(3'hz, i2c_sda);
                `util_assert_equal(3'hz, i2c_scl);

                select_control(0, 1, 2);

                // Set pin mapping
                pin_map_set(sda_in_index, SYS_I2C_LOGICAL_SDA_IN);
                pin_map_set(sda_val_index, SYS_I2C_LOGICAL_SDA_VAL);
                pin_map_set(scl_val_index, SYS_I2C_LOGICAL_SCL_VAL);

                // Verify that I2C pins are high-z
                `util_assert_equal(3'hz, i2c_sda);
                `util_assert_equal(3'hz, i2c_scl);

                // Enable I2C mode
                start_transfer(ADDR_SYS_PIN_MODE, 1, 1);
                if (i == 0) begin
                    spi.send(SYS_PIN_MODE_I2C0);
                end
                else if (i == 1) begin
                    spi.send(SYS_PIN_MODE_I2C1);
                end
                else if (i == 2) begin
                    spi.send(SYS_PIN_MODE_I2C2);
                end

                // Verify that I2C pins are driven from the right source
                `util_assert_equal(io_reg[sda_in_index], i2c_sda[i]);
                `util_assert_equal(io_reg[scl_in_index], i2c_scl[i]);

                io_reg[sda_val_index] = 0;
                io_reg[scl_val_index] = 0;
                #100
                `util_assert_equal(0, i2c_sda[i]);
                `util_assert_equal(0, i2c_scl[i]);

                io_reg[sda_val_index] = 0;
                io_reg[scl_val_index] = 1;
                #100
                `util_assert_equal(0, i2c_sda[i]);
                `util_assert_equal(1'bz, i2c_scl[i]);

                io_reg[sda_val_index] = 1;
                io_reg[scl_val_index] = 0;
                #100
                `util_assert_equal(1'bz, i2c_sda[i]);
                `util_assert_equal(0, i2c_scl[i]);

                io_reg[sda_val_index] = 1;
                io_reg[scl_val_index] = 1;
                #100
                `util_assert_equal(1'bz, i2c_sda[i]);
                `util_assert_equal(1'bz, i2c_scl[i]);

                // Disable I2C mode
                start_transfer(ADDR_SYS_PIN_MODE, 1, 1);
                spi.send(SYS_PIN_MODE_OFF);

                // Verify that I2C pins are high-z
                `util_assert_equal(3'hz, i2c_sda);
                `util_assert_equal(3'hz, i2c_scl);

                io_reg[sda_val_index] = 1'bz;
                io_reg[scl_val_index] = 1'bz;
            end
        end
    endtask

    localparam TESTER_SYS_IO_MODE             = 32'h00002C00;
    localparam TESTER_SYS_IO_PWM_ENABLE       = 32'h00002C01;
    localparam TESTER_SYS_IO_PWM_PERIOD       = 32'h00002C02;
    localparam TESTER_SYS_IO_PWM_DUTY_CYCLE   = 32'h00002C06;

    task sys_pwm_testcase;
        reg write_n_read;
        integer transfers;
        reg [IO_LOGICAL - 1:0] expected;
        integer i, j;
        reg [31:0] period;
        reg [31:0] duty_cycle;
        reg [31:0] pwm_high;
        reg [7:0] measured_duty_cycle;
        begin
            expected = 'hz;
            spi.period = 200;
            reset(20);

            // Map all pins to nothing
            select_control(0, 1, 2);
            write_n_read = 1;
            transfers = IO_PHYSICAL + IO_LOGICAL;
            start_transfer(ADDR_BASE_MUX, write_n_read, transfers);
            for (i = 0; i < transfers; i = i + 1) begin
                spi.send('hFF);
            end

            //set period to 1000ns
            transfers = 4;
            period = (1000 / 10) - 1;//period = 1000ns = 100 clk cycles
            start_transfer(TESTER_SYS_IO_PWM_PERIOD, write_n_read, transfers);
            spi.send(period[7:0]);
            spi.send(period[15:8]);
            spi.send(period[23:16]);
            spi.send(period[31:24]);
            //set duty cycle to 0
            transfers = 4;
            duty_cycle = 0;
            start_transfer(TESTER_SYS_IO_PWM_DUTY_CYCLE, write_n_read, transfers);
            spi.send(duty_cycle[7:0]);
            spi.send(duty_cycle[15:8]);
            spi.send(duty_cycle[23:16]);
            spi.send(duty_cycle[31:24]);
            //set enable to 1
            transfers = 1;
            start_transfer(TESTER_SYS_IO_PWM_ENABLE, write_n_read, transfers);
            spi.send(1);
            // test duty cycles 0-100% at 1000ns period
            for (i = 0; i < 11; i = i + 1) begin
                duty_cycle = (10 * i * (period + 1)) / 100;
                transfers = 4;
                start_transfer(TESTER_SYS_IO_PWM_DUTY_CYCLE, write_n_read, transfers);
                spi.send(duty_cycle[7:0]);
                spi.send(duty_cycle[15:8]);
                spi.send(duty_cycle[23:16]);
                spi.send(duty_cycle[31:24]);
                pwm_high = 0;
                j = 0;
                while (j < 5000) begin
                    if (an_mux_pwmout == 1) begin
                        pwm_high = pwm_high + 1;
                    end
                j = j + 1;
                #1;
                end
                measured_duty_cycle = pwm_high / 50;
                //assert produced pwm signal duty cycle is within 1 clk cycle of original duty cycle
                if ((measured_duty_cycle != (duty_cycle-1)) && (measured_duty_cycle != (duty_cycle)) && (measured_duty_cycle != (duty_cycle+1))) begin
                    `util_assert_equal(duty_cycle, measured_duty_cycle);
                end
            end
            //disable sys pwm
            start_transfer(TESTER_SYS_IO_PWM_ENABLE, write_n_read, transfers);
            spi.send(0);
            #5000;

        end
    endtask

    initial begin
        normal_operation_testcase();
        sys_io_testcase();
        sys_pin_mode_testcase();
        sys_pin_mode_i2c_testcase();
        sys_pwm_testcase();
        -> terminate_sim;
    end

endmodule
