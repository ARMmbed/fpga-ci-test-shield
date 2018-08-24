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

`define ANIN_MEASUREMENT_SNAPSHOT_START_ADDR  12'hC30
`define ANIN_MEASUREMENT_SNAPSHOT_SIZE        2
`define ANIN_MEASUREMENTS_SUM_SNAPSHOT_SIZE   8

module mbed_tester #(
        parameter IO_PHYSICAL = 16,
        parameter IO_LOGICAL_PER_BANK = 8,
        parameter IO_BANKS = 2,
        parameter DIGITAL_ID_COUNT = 3,
        parameter LED_COUNT = 4,
        parameter I2C_COUNT = 3,
        parameter AN_MUX_WIDTH = 8,
        parameter ANALOG_COUNT = 4
    )
    (
        input wire clk,
        input wire rst,
        output wire reset_req,
        output wire reprogram_req,

        input wire [IO_PHYSICAL - 1:0] io_in,
        output wire [IO_PHYSICAL - 1:0] io_val,
        output wire [IO_PHYSICAL - 1:0] io_drive,

        input wire reset_btn_in,
        output wire reset_btn_val,
        output wire reset_btn_drive,
        input wire reprogram_in,
        output wire reprogram_val,
        output wire reprogram_drive,
        input wire [DIGITAL_ID_COUNT - 1:0] digital_id_in,
        output wire [DIGITAL_ID_COUNT - 1:0] digital_id_val,
        output wire [DIGITAL_ID_COUNT - 1:0] digital_id_drive,
        input wire [LED_COUNT - 1:0] leds_in,
        output wire [LED_COUNT - 1:0] leds_val,
        output wire [LED_COUNT - 1:0] leds_drive,

        input wire [3:0] spi_io_in,
        output reg [3:0] spi_io_val,
        output reg [3:0] spi_io_drive,
        input wire spi_clk_in,
        output reg spi_clk_val,
        output reg spi_clk_drive,
        input wire spi_cs_in,
        output reg spi_cs_val,
        output reg spi_cs_drive,

        input wire i2c_reset_in,
        output wire i2c_reset_val,
        output wire i2c_reset_drive,
        input wire [I2C_COUNT - 1:0] i2c_sda_in,
        output reg [I2C_COUNT - 1:0] i2c_sda_val,
        output reg [I2C_COUNT - 1:0] i2c_sda_drive,
        input wire [I2C_COUNT - 1:0] i2c_scl_in,
        output reg [I2C_COUNT - 1:0] i2c_scl_val,
        output reg [I2C_COUNT - 1:0] i2c_scl_drive,

        input wire an_mux_enable_in,
        output wire an_mux_enable_val,
        output wire an_mux_enable_drive,
        input wire an_mux_pwmout_in,
        output reg an_mux_pwmout_val,
        output reg an_mux_pwmout_drive,
        input wire an_mux_analogin_in,
        output wire an_mux_analogin_val,
        output wire an_mux_analogin_drive,
        input wire [AN_MUX_WIDTH - 1:0] an_mux_addr_in,
        output wire [AN_MUX_WIDTH - 1:0] an_mux_addr_val,
        output wire [AN_MUX_WIDTH - 1:0] an_mux_addr_drive,

        input wire [ANALOG_COUNT - 1:0] aninp_in,
        output wire [ANALOG_COUNT - 1:0] aninp_val,
        output wire [ANALOG_COUNT - 1:0] aninp_drive,
        input wire [ANALOG_COUNT - 1:0] aninn_in,
        output wire [ANALOG_COUNT - 1:0] aninn_val,
        output wire [ANALOG_COUNT - 1:0] aninn_drive,

        input wire [11:0] an_mux_analogin_measurement_in,
        input wire [(ANALOG_COUNT * 12) - 1:0] anin_measurements_in,
        input wire an_mux_analogin_updated,
        input wire [ANALOG_COUNT - 1:0] anin_updated,
        // + 0xC19 - 0: XADC off, 1: XADC on
        output reg sample_adc
    );
    localparam IO_LOGICAL_TOTAL = IO_LOGICAL_PER_BANK * (IO_BANKS + 1);
    localparam ADDR_BYTES = 4;
    localparam ADDR_BITS = ADDR_BYTES * 8;
    localparam ADDR_LOW_BITS = 20;
    localparam ADDR_HIGH_BITS = ADDR_BITS - ADDR_LOW_BITS;
    localparam CONTROL_LINES = IO_PHYSICAL / 2;
    localparam APB_SLAVE_COUNT = 3;
    localparam DATA_BITS = 8;

    localparam MBED_TESTER_VERSION = 'h00000001;

    reg reset_all;

    wire [IO_PHYSICAL - 1:0] physical_in;
    wire [IO_PHYSICAL - 1:0] physical_val;
    wire [IO_PHYSICAL - 1:0] physical_drive;
    wire [IO_PHYSICAL - 1:0] physical_override;

    wire [IO_PHYSICAL - 1:0] physical_mux_val;
    wire [IO_PHYSICAL - 1:0] physical_mux_drive;

    wire [IO_LOGICAL_TOTAL - 1:0] logical_in;
    wire [IO_LOGICAL_TOTAL - 1:0] logical_val;
    wire [IO_LOGICAL_TOTAL - 1:0] logical_drive;

    wire [CONTROL_LINES - 1:0] control_sclks;
    wire [CONTROL_LINES - 1:0] control_sins;
    wire [7:0] control_sout_index;
    wire control_sout_enable;
    wire control_sout;
    wire spi_start, spi_next, spi_stop;
    wire [7:0] from_spi;
    wire [7:0] to_spi;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    wire [ADDR_LOW_BITS - 1:0] paddr_low;
    wire [ADDR_HIGH_BITS - 1:0] paddr_high;

    wire [APB_SLAVE_COUNT * DATA_BITS - 1:0] PRDATAs;
    wire [APB_SLAVE_COUNT - 1:0] PSELs;

    wire mbed_tester_control_psel;
    wire [DATA_BITS - 1:0] mbed_tester_control_prdata;

    wire mbed_tester_peripherals_a_psel;
    wire [DATA_BITS - 1:0] mbed_tester_peripherals_a_prdata;

    wire mbed_tester_peripherals_b_psel;
    wire [DATA_BITS - 1:0] mbed_tester_peripherals_b_prdata;

    genvar i_gen;

    assign physical_in = io_in;
    assign io_val = physical_val;
    assign io_drive = physical_drive;

    assign paddr_low = PADDR[ADDR_LOW_BITS - 1:0];
    assign paddr_high = PADDR[ADDR_HIGH_BITS + ADDR_LOW_BITS - 1:ADDR_LOW_BITS];

    /* Peripheral mapping */

    assign mbed_tester_control_psel = PSELs[0];         // 0x00000000
    assign mbed_tester_peripherals_a_psel = PSELs[1];   // 0x00100000
    assign mbed_tester_peripherals_b_psel = PSELs[2];   // 0x00200000

    assign PRDATAs[0 * DATA_BITS+:DATA_BITS] = mbed_tester_control_prdata;
    assign PRDATAs[1 * DATA_BITS+:DATA_BITS] = mbed_tester_peripherals_a_prdata;
    assign PRDATAs[2 * DATA_BITS+:DATA_BITS] = mbed_tester_peripherals_b_prdata;

    /* Control IO override */
    for (i_gen = 0; i_gen < IO_PHYSICAL; i_gen = i_gen + 1) begin
        assign physical_override[i_gen] = control_sout_enable && (i_gen == control_sout_index);
        assign physical_val[i_gen] = physical_override[i_gen] ? control_sout : physical_mux_val[i_gen];
        assign physical_drive[i_gen] = physical_override[i_gen] ? 1 : physical_mux_drive[i_gen];
    end

    /* Route SPI lines to control manager */
    for (i_gen = 0; i_gen < CONTROL_LINES; i_gen = i_gen + 1) begin
        assign control_sclks[i_gen] = physical_in[i_gen * 2];
        assign control_sins[i_gen] = physical_in[i_gen * 2 + 1];
    end

    control_manager #(.SPI_COUNT(CONTROL_LINES), .ADDR_BYTES(ADDR_BYTES)) control_manager(
        .clk(clk),
        .rst(rst),
        .sclks(control_sclks),
        .sins(control_sins),
        .sout_index(control_sout_index),
        .sout_enable(control_sout_enable),
        .sout(control_sout),

        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    slave_mux_apb2_slave #(.SELECTOR_BITS(ADDR_HIGH_BITS), .DATA_BITS(DATA_BITS), .SLAVES(APB_SLAVE_COUNT)) slave_mux_apb2_slave (
        .select(paddr_high),
        .PSEL(PSEL),
        .PRDATA(PRDATA),
        .PSELs(PSELs),
        .PRDATAs(PRDATAs)
    );

    /* Peripheral bank A - uses the first IO_LOGICAL_PER_BANK logical pins */
    mbed_tester_peripherals_apb2_slave #(.IO_LOGICAL(IO_LOGICAL_PER_BANK)) mbed_tester_peripherals_apb2_slave_a(
        .clk(clk),
        .rst(rst || reset_all),

        .logical_in(logical_in[0 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),
        .logical_val(logical_val[0 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),
        .logical_drive(logical_drive[0 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),

        .PADDR(paddr_low),
        .PSEL(mbed_tester_peripherals_a_psel),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(mbed_tester_peripherals_a_prdata)
    );

    /* Peripheral bank B - uses the second IO_LOGICAL_PER_BANK logical pins */
    mbed_tester_peripherals_apb2_slave #(.IO_LOGICAL(IO_LOGICAL_PER_BANK)) mbed_tester_peripherals_apb2_slave_b(
        .clk(clk),
        .rst(rst || reset_all),

        .logical_in(logical_in[1 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),
        .logical_val(logical_val[1 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),
        .logical_drive(logical_drive[1 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK]),

        .PADDR(paddr_low),
        .PSEL(mbed_tester_peripherals_b_psel),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(mbed_tester_peripherals_b_prdata)
    );

    /* System control */

    localparam LOCAL_SLAVE_COUNT = 3;

    wire control_psel;
    wire multiplexer_psel;
    wire sys_io_psel;

    assign control_psel = LOCAL_PSELs[0];       // 0x00000
    assign multiplexer_psel = LOCAL_PSELs[1];   // 0x01000
    assign sys_io_psel = LOCAL_PSELs[2];        // 0x02000

    reg [DATA_BITS - 1:0] control_prdata;
    wire [DATA_BITS - 1:0] multiplexer_prdata;
    reg [DATA_BITS - 1:0] sys_io_prdata;

    assign LOCAL_PRDATAs[0 * DATA_BITS+:DATA_BITS] = control_prdata;
    assign LOCAL_PRDATAs[1 * DATA_BITS+:DATA_BITS] = multiplexer_prdata;
    assign LOCAL_PRDATAs[2 * DATA_BITS+:DATA_BITS] = sys_io_prdata;

    /*
     * PADDR[32]            = |------------------------------|
     *
     * paddr_high[12]       = |----------|
     * paddr_low[20]        =             |------------------|
     * paddr_low_top[8]     =             |------|
     * paddr_low_bottom[12] =                     |----------|
     */
    localparam ADDR_LOW_BOTTOM_BITS = 12;
    localparam ADDR_LOW_TOP_BITS = ADDR_LOW_BITS - ADDR_LOW_BOTTOM_BITS;

    wire [ADDR_LOW_TOP_BITS - 1:0] paddr_low_top;
    wire [ADDR_LOW_BOTTOM_BITS - 1:0] paddr_low_bottom;

    assign paddr_low_top = paddr_low[ADDR_LOW_TOP_BITS + ADDR_LOW_BOTTOM_BITS - 1:ADDR_LOW_BOTTOM_BITS];
    assign paddr_low_bottom = paddr_low[ADDR_LOW_BOTTOM_BITS - 1:0];

    wire [LOCAL_SLAVE_COUNT * DATA_BITS - 1:0] LOCAL_PRDATAs;
    wire [LOCAL_SLAVE_COUNT - 1:0] LOCAL_PSELs;

    slave_mux_apb2_slave #(.SELECTOR_BITS(ADDR_LOW_TOP_BITS), .DATA_BITS(DATA_BITS), .SLAVES(LOCAL_SLAVE_COUNT)) slave_mux_apb2_slave_low (
        .select(paddr_low_top),
        .PSEL(mbed_tester_control_psel),
        .PRDATA(mbed_tester_control_prdata),
        .PSELs(LOCAL_PSELs),
        .PRDATAs(LOCAL_PRDATAs)
    );

    // Control +0x0000
    reg reset_req_reg;
    reg reprogram_req_reg;

    assign reset_req = reset_req_reg || !reset_btn_in;
    assign reprogram_req = reprogram_req_reg;

    always @(posedge clk) begin
        if (rst) begin
            control_prdata <= 0;
            reset_req_reg <= 0;
            reprogram_req_reg <= 0;
            reset_all <= 0;
        end else begin
            reset_all <= 0;
            if (control_psel) begin
                if (PWRITE && PENABLE) begin
                    case (paddr_low_bottom)

                        // Reset
                        // 0 - peripheral banks
                        // 1 - software system reset
                        // 2 - reprogram reset
                        0: {reprogram_req_reg, reset_req_reg, reset_all} <= PWDATA[2:0];

                        default:;
                    endcase
                end
                if (!PWRITE) begin
                    case (paddr_low_bottom)

                        // ID
                        12'h000: control_prdata <= "m";
                        12'h001: control_prdata <= "b";
                        12'h002: control_prdata <= "e";
                        12'h003: control_prdata <= "d";

                        // Software version
                        12'h010: control_prdata <= MBED_TESTER_VERSION[0 * DATA_BITS+:DATA_BITS];
                        12'h011: control_prdata <= MBED_TESTER_VERSION[1 * DATA_BITS+:DATA_BITS];
                        12'h012: control_prdata <= MBED_TESTER_VERSION[2 * DATA_BITS+:DATA_BITS];
                        12'h013: control_prdata <= MBED_TESTER_VERSION[3 * DATA_BITS+:DATA_BITS];

                        // Hardware ID
                        12'h014: control_prdata <= digital_id_in;

                        // IO Info
                        12'h020: control_prdata <= IO_PHYSICAL;
                        12'h021: control_prdata <= IO_LOGICAL_PER_BANK;
                        12'h022: control_prdata <= IO_BANKS;

                        // Dynamically configurable pins
                        12'h030: control_prdata <= DIGITAL_ID_COUNT;
                        12'h031: control_prdata <= LED_COUNT;
                        12'h032: control_prdata <= I2C_COUNT;
                        12'h033: control_prdata <= AN_MUX_WIDTH;
                        12'h034: control_prdata <= ANALOG_COUNT;

                        default: control_prdata <= 0;
                    endcase
                end
            end
        end
    end

    // IO multiplexer + 0x1000
    io_multiplexer_apb2_slave #(.IO_PHYSICAL(IO_PHYSICAL), .IO_LOGICAL(IO_LOGICAL_TOTAL)) io_multiplexer_apb2_slave(
        .clk(clk),
        .rst(rst),

        .physical_in(physical_in),
        .physical_val(physical_mux_val),
        .physical_drive(physical_mux_drive),
        .logical_in(logical_in),
        .logical_val(logical_val),
        .logical_drive(logical_drive),

        .PADDR(paddr_low_bottom),
        .PSEL(multiplexer_psel),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(multiplexer_prdata)
    );

    // System IO + 0x2000
    localparam SYS_IO_COUNT = 12 + ANALOG_COUNT * 2 + AN_MUX_WIDTH + I2C_COUNT * 2 + LED_COUNT + DIGITAL_ID_COUNT;

    // Special IO modes
    localparam SYS_IO_MODE_DISABLED = 0;
    localparam SYS_IO_MODE_SPI_SERIAL_FLASH = 1;
    localparam SYS_IO_MODE_I2C_IO_EXPANDER = 2;

    wire [SYS_IO_COUNT - 1:0] sys_io_in;
    reg [SYS_IO_COUNT - 1:0] sys_io_val;
    reg [SYS_IO_COUNT - 1:0] sys_io_drive;

    reg [7:0] sys_io_mode;

    wire [IO_LOGICAL_PER_BANK - 1:0] sys_logical_in;
    reg [IO_LOGICAL_PER_BANK - 1:0] sys_logical_val;
    reg [IO_LOGICAL_PER_BANK - 1:0] sys_logical_drive;

    assign sys_logical_in = logical_in[2 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK];
    assign logical_val[2 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK] = sys_logical_val;
    assign logical_drive[2 * IO_LOGICAL_PER_BANK+: IO_LOGICAL_PER_BANK] = sys_logical_drive;

    wire [3:0] sys_io_spi_io_val;
    wire [3:0] sys_io_spi_io_drive;
    wire sys_io_spi_clk_val;
    wire sys_io_spi_clk_drive;
    wire sys_io_spi_cs_val;
    wire sys_io_spi_cs_drive;

    wire [I2C_COUNT - 1:0] sys_io_i2c_sda_val;
    wire [I2C_COUNT - 1:0] sys_io_i2c_sda_drive;
    wire [I2C_COUNT - 1:0] sys_io_i2c_scl_val;
    wire [I2C_COUNT - 1:0] sys_io_i2c_scl_drive;

    wire sys_io_an_mux_pwmout_val;
    wire sys_io_an_mux_pwmout_drive;

    always @(*) begin: io_modes
        integer i;

        // Initialize pins
        for (i = 0; i < IO_LOGICAL_PER_BANK; i = i + 1) begin
            sys_logical_val[i] = 0;
            sys_logical_drive[i] = 0;
        end

        spi_io_val = sys_io_spi_io_val;
        spi_io_drive = sys_io_spi_io_drive;
        spi_clk_val = sys_io_spi_clk_val;
        spi_clk_drive = sys_io_spi_clk_drive;
        spi_cs_val = sys_io_spi_cs_val;
        spi_cs_drive = sys_io_spi_cs_drive;

        i2c_scl_val = sys_io_i2c_scl_val;
        i2c_scl_drive = sys_io_i2c_scl_drive;
        i2c_sda_val = sys_io_i2c_sda_val;
        i2c_sda_drive = sys_io_i2c_sda_drive;

        if (sys_io_mode == SYS_IO_MODE_SPI_SERIAL_FLASH) begin

            // 0 is mosi
            // Input on the mbed side
            sys_logical_val[0] = 0;
            sys_logical_drive[0] = 0;
            // Output on the flash side
            spi_io_val[0] = sys_logical_in[0];
            spi_io_drive[0] = 1;

            // 1 is miso - always an input
            // Output on the mbed side
            sys_logical_val[1] = spi_io_in[1];
            sys_logical_drive[1] = 1;
            // Input on the flash side
            spi_io_val[1] = 0;
            spi_io_drive[1] = 0;

            // 2 is clock
            // Input on the mbed side
            sys_logical_val[2] = 0;
            sys_logical_drive[2] = 0;
            // Output on the flash side
            spi_clk_val = sys_logical_in[2];
            spi_clk_drive = 1;


            // 3 is chip select - always an output
            // Input on the mbed side
            sys_logical_val[3] = 0;
            sys_logical_drive[3] = 0;
            // Output on the flash side
            spi_cs_val = sys_logical_in[3];
            spi_cs_drive = 1;

            // Hold - always driven 1
            spi_io_val[2] = 1;
            spi_io_drive[2] = 1;
            // write protect always driven 1
            spi_io_val[3] = 1;
            spi_io_drive[3] = 1;
        end

        if ((sys_io_mode >= SYS_IO_MODE_I2C_IO_EXPANDER) && (sys_io_mode < SYS_IO_MODE_I2C_IO_EXPANDER + I2C_COUNT)) begin
            i = sys_io_mode - SYS_IO_MODE_I2C_IO_EXPANDER;

            // 0 is sda read
            sys_logical_val[0] = i2c_sda_in[i];
            sys_logical_drive[0] = 1;

            // 1 is sda write
            sys_logical_val[1] = 0;
            sys_logical_drive[1] = 0;
            i2c_sda_val[i] = 0;
            i2c_sda_drive[i] = !sys_logical_in[1];

            // 2 is scl read
            sys_logical_val[2] = i2c_scl_in[i];
            sys_logical_drive[2] = 1;

            // 3 is scl write
            sys_logical_val[3] = 0;
            sys_logical_drive[3] = 0;
            i2c_scl_val[i] = 0;
            i2c_scl_drive[i] = !sys_logical_in[3];
        end

    end

    //System PWM Logic

    // + 0xC01 - 0: PWM off, 1: PWM on
    reg pwm_enable;
    // + 0xC02 - Period in clk cycles
    reg [31:0] pwm_period;
    // + 0xC06 - Cycles high in clk cycles - (cycles_high / period = duty_cycle)
    reg [31:0] pwm_cycles_high;

    reg [31:0] pwm_count;
    reg [31:0] pwm_count_reg;

    always @(*) begin
        pwm_count = pwm_count_reg;
        an_mux_pwmout_val = sys_io_an_mux_pwmout_val;
        an_mux_pwmout_drive = sys_io_an_mux_pwmout_drive;
        if (rst == 0) begin
            if (pwm_enable) begin
                an_mux_pwmout_drive = 1;
                if (pwm_count < pwm_cycles_high) begin
                    an_mux_pwmout_val = 1;
                end else begin
                    an_mux_pwmout_val = 0;
                end
                if (pwm_count < pwm_period) begin
                    pwm_count = pwm_count_reg + 1;
                end else begin
                    pwm_count = 0;
                end
            end else begin
                pwm_count = 0;
            end
        end else begin // rst == 1
            pwm_count = 0;
        end
    end

    always @(posedge clk) begin
        pwm_count_reg <= pwm_count;
    end

    // System XADC Logic

    // Snapshot registers

    // + 0xC0A - XADC result for AN_MUX_ANALOGIN
    reg [15:0] an_mux_analogin_measurement_snapshot;
    // + 0xC0C - Number of XADC sample sequences that have completed since the XADC was turned on (power measurements)
    reg [31:0] num_power_samples_snapshot;
    // + 0xC10 - Number of FPGA clk cycles that occur while the FPGA ADC is active
    reg [63:0] num_power_cycles_snapshot;
    // + 0xC30, 0xC3A, 0xC44, 0xC4E - XADC result for ANIN pins
    reg [15:0] anin_measurement_snapshot [3:0];
    // + 0xC32, 0xC3C, 0xC46, 0xC50 - Array of regs of sums of all ANIN XADC results
    reg [63:0] anin_measurements_sum_snapshot [3:0];

    // + 0xC18 - 0: XADC registers not snapshotted, 1: XADC registers are snapshotted for 1 clk cycle
    reg adc_snapshot;

    reg [15:0] an_mux_analogin_measurement_reg;
    reg [31:0] num_power_samples_reg;
    reg [63:0] num_power_cycles_reg;
    reg [15:0] anin_measurement_reg [3:0];
    reg [63:0] anin_measurements_sum_reg [3:0];
    reg [7:0] num_conversions_reg;

    reg [15:0] an_mux_analogin_measurement;
    reg [31:0] num_power_samples;
    reg [63:0] num_power_cycles;
    reg [15:0] anin_measurement [3:0];
    reg [63:0] anin_measurements_sum [3:0];
    reg [7:0] num_conversions;

    // Sync registers
    reg [15:0] an_mux_analogin_measurement_sync;
    reg [15:0] an_mux_analogin_measurement_sync_reg;
    reg [15:0] anin_measurement_sync [3:0];
    reg [15:0] anin_measurement_sync_reg [3:0];

    always @(*) begin: adc_combinational
        integer i;
        if (rst == 0) begin
            an_mux_analogin_measurement = an_mux_analogin_measurement_reg;
            num_power_samples = num_power_samples_reg;
            num_power_cycles  = num_power_cycles_reg;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurement[i] = anin_measurement_reg[i];
            end
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurements_sum[i] = anin_measurements_sum_reg[i];
            end
            num_conversions = num_conversions_reg;
            an_mux_analogin_measurement_sync = an_mux_analogin_measurement_sync_reg;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurement_sync[i] = anin_measurement_sync_reg[i];
            end
            if (sample_adc) begin
                num_power_cycles = num_power_cycles_reg + 1;
                if (an_mux_analogin_updated) begin
                    an_mux_analogin_measurement = {4'b0000,an_mux_analogin_measurement_in[11:0]};
                    num_conversions = num_conversions_reg + 1;
                end
                //check for updated power adc results
                for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                    if (anin_updated[i]) begin//new adc sample ready
                        anin_measurement[i] = {4'b0000,anin_measurements_in[(i * 12)+:12]};
                        anin_measurements_sum[i] = anin_measurements_sum_reg[i] + anin_measurements_in[(i * 12)+:12];
                        num_conversions = num_conversions_reg + 1;
                    end
                end
                if (num_conversions == (ANALOG_COUNT + 1)) begin
                    //last adc in sequence to be sampled
                    num_power_samples = num_power_samples_reg + 1;
                    an_mux_analogin_measurement_sync = an_mux_analogin_measurement_reg;
                    for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                        anin_measurement_sync[i] = anin_measurement_reg[i];
                    end
                    num_conversions = 0;
                end
            end
        end else begin//rst == 1
            an_mux_analogin_measurement = 0;
            num_power_samples = 0;
            num_power_cycles = 0;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurement[i] = 0;
            end
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurements_sum[i] = 0;
            end
            num_conversions = 0;
            an_mux_analogin_measurement_sync = 0;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurement_sync[i] = 0;
            end
        end
    end

    always @(posedge clk) begin: adc_sequential
        integer i;
        an_mux_analogin_measurement_reg <= an_mux_analogin_measurement;
        num_power_samples_reg <= num_power_samples;
        num_power_cycles_reg <= num_power_cycles;
        for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
            anin_measurement_reg[i] <= anin_measurement[i];
        end
        for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
            anin_measurements_sum_reg[i] <= anin_measurements_sum[i];
        end
        num_conversions_reg <= num_conversions;
        an_mux_analogin_measurement_sync_reg <= an_mux_analogin_measurement_sync;
        for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
            anin_measurement_sync_reg[i] <= anin_measurement_sync[i];
        end
    end

    // Note - first entry in this concatination is at the bottom
    assign sys_io_in = {
                                //                      12 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2 + AN_MUX_WIDTH + ANALOG_COUNT * 2
        aninn_in,               // ANALOG_COUNT         12 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2 + AN_MUX_WIDTH + ANALOG_COUNT
        aninp_in,               // ANALOG_COUNT         12 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2 + AN_MUX_WIDTH
        an_mux_addr_in,         // AN_MUX_WIDTH         12 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2
        an_mux_analogin_in,     // 1                    11 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2
        an_mux_pwmout_in,       // 1                    10 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2
        an_mux_enable_in,       // 1                    9 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT * 2
        i2c_scl_in,             // I2C_COUNT            9 + DIGITAL_ID_COUNT + LED_COUNT + I2C_COUNT
        i2c_sda_in,             // I2C_COUNT            9 + DIGITAL_ID_COUNT + LED_COUNT
        i2c_reset_in,           // 1                    8 + DIGITAL_ID_COUNT + LED_COUNT
        spi_cs_in,              // 1                    7 + DIGITAL_ID_COUNT + LED_COUNT
        spi_clk_in,             // 1                    6 + DIGITAL_ID_COUNT + LED_COUNT
        spi_io_in,              // 4                    2 + DIGITAL_ID_COUNT + LED_COUNT
        leds_in,                // LED_COUNT            2 + DIGITAL_ID_COUNT
        digital_id_in,          // DIGITAL_ID_COUNT     2
        reprogram_in,           // 1                    1
        reset_btn_in            // 1                    0
    };

    assign {
        aninn_val,
        aninp_val,
        an_mux_addr_val,
        an_mux_analogin_val,
        sys_io_an_mux_pwmout_val,
        an_mux_enable_val,
        sys_io_i2c_scl_val,
        sys_io_i2c_sda_val,
        i2c_reset_val,
        sys_io_spi_cs_val,
        sys_io_spi_clk_val,
        sys_io_spi_io_val,
        leds_val,
        digital_id_val,
        reprogram_val,
        reset_btn_val
    } = sys_io_val;

    assign {
        aninn_drive,
        aninp_drive,
        an_mux_addr_drive,
        an_mux_analogin_drive,
        sys_io_an_mux_pwmout_drive,
        an_mux_enable_drive,
        sys_io_i2c_scl_drive,
        sys_io_i2c_sda_drive,
        i2c_reset_drive,
        sys_io_spi_cs_drive,
        sys_io_spi_clk_drive,
        sys_io_spi_io_drive,
        leds_drive,
        digital_id_drive,
        reprogram_drive,
        reset_btn_drive
    } = sys_io_drive;

    always @(posedge clk) begin: mbed_tester_registers
        integer i;
        integer j;
        if (rst) begin
            sys_io_val <= 0;
            sys_io_drive <= 0;
            sys_io_prdata <= 0;
            sys_io_mode <= SYS_IO_MODE_DISABLED;
            pwm_enable <= 0;
            pwm_period <= 0;
            pwm_cycles_high <= 0;
            an_mux_analogin_measurement_snapshot <= 0;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurement_snapshot[i] <= 0;
            end
            num_power_samples_snapshot <= 0;
            num_power_cycles_snapshot <= 0;
            for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                anin_measurements_sum_snapshot[i] <= 0;
            end
            adc_snapshot <= 0;
        end else begin
            // XADC snapshot registers for reading
            if (adc_snapshot) begin
                an_mux_analogin_measurement_snapshot <= an_mux_analogin_measurement_sync;
                num_power_samples_snapshot <= num_power_samples;
                num_power_cycles_snapshot <= num_power_cycles;
                for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                    anin_measurement_snapshot[i] <= anin_measurement_sync[i];
                end
                for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                    anin_measurements_sum_snapshot[i] <= anin_measurements_sum[i];
                end
                adc_snapshot <= 0;
            end

            if (sys_io_psel) begin
                if (PWRITE && PENABLE) begin
                    if (paddr_low_bottom < SYS_IO_COUNT) begin
                        // Write to SYSIO
                        sys_io_val[paddr_low_bottom] <= PWDATA[0];
                        sys_io_drive[paddr_low_bottom] <= PWDATA[1];
                    end

                    if (paddr_low_bottom == 12'hC00) begin
                        sys_io_mode <=  PWDATA;
                    end

                    if (paddr_low_bottom == 12'hC01) begin
                        pwm_enable <= PWDATA[0];
                    end

                    if (paddr_low_bottom == 12'hC02) begin
                        pwm_period[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC03) begin
                        pwm_period[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC04) begin
                        pwm_period[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC05) begin
                        pwm_period[DATA_BITS * 3+:DATA_BITS] <= PWDATA;
                    end

                    if (paddr_low_bottom == 12'hC06) begin
                        pwm_cycles_high[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC07) begin
                        pwm_cycles_high[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC08) begin
                        pwm_cycles_high[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                    end
                    if (paddr_low_bottom == 12'hC09) begin
                        pwm_cycles_high[DATA_BITS * 3+:DATA_BITS] <= PWDATA;
                    end

                    if (paddr_low_bottom == 12'hC18) begin
                        adc_snapshot <= PWDATA[0];
                    end

                    if (paddr_low_bottom == 12'hC19) begin
                        sample_adc <= PWDATA[0];
                    end
                end
                if (!PWRITE) begin
                    if (paddr_low_bottom < SYS_IO_COUNT) begin
                        // Read from SYSIO
                        sys_io_prdata <= sys_io_in[paddr_low_bottom];
                    end else begin
                        sys_io_prdata <= 0;
                    end

                    if (paddr_low_bottom == 12'hC00) begin
                        sys_io_prdata <= sys_io_mode;
                    end

                    if (paddr_low_bottom == 12'hC01) begin
                        sys_io_prdata <= {7'h00, pwm_enable};
                    end

                    if (paddr_low_bottom == 12'hC02) begin
                        sys_io_prdata <= pwm_period[DATA_BITS * 0+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC03) begin
                        sys_io_prdata <= pwm_period[DATA_BITS * 1+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC04) begin
                        sys_io_prdata <= pwm_period[DATA_BITS * 2+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC05) begin
                        sys_io_prdata <= pwm_period[DATA_BITS * 3+:DATA_BITS];
                    end

                    if (paddr_low_bottom == 12'hC06) begin
                        sys_io_prdata <= pwm_cycles_high[DATA_BITS * 0+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC07) begin
                        sys_io_prdata <= pwm_cycles_high[DATA_BITS * 1+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC08) begin
                        sys_io_prdata <= pwm_cycles_high[DATA_BITS * 2+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC09) begin
                        sys_io_prdata <= pwm_cycles_high[DATA_BITS * 3+:DATA_BITS];
                    end

                    if (paddr_low_bottom == 12'hC0A) begin
                        sys_io_prdata <= an_mux_analogin_measurement_snapshot[DATA_BITS * 0+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC0B) begin
                        sys_io_prdata <= an_mux_analogin_measurement_snapshot[DATA_BITS * 1+:DATA_BITS];
                    end

                    if (paddr_low_bottom == 12'hC0C) begin
                        sys_io_prdata <= num_power_samples_snapshot[DATA_BITS * 0+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC0D) begin
                        sys_io_prdata <= num_power_samples_snapshot[DATA_BITS * 1+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC0E) begin
                        sys_io_prdata <= num_power_samples_snapshot[DATA_BITS * 2+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC0F) begin
                        sys_io_prdata <= num_power_samples_snapshot[DATA_BITS * 3+:DATA_BITS];
                    end

                    if (paddr_low_bottom == 12'hC10) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 0+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC11) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 1+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC12) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 2+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC13) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 3+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC14) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 4+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC15) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 5+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC16) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 6+:DATA_BITS];
                    end
                    if (paddr_low_bottom == 12'hC17) begin
                        sys_io_prdata <= num_power_cycles_snapshot[DATA_BITS * 7+:DATA_BITS];
                    end

                    for (i = 0; i < ANALOG_COUNT; i = i + 1) begin
                        for (j = 0; j < `ANIN_MEASUREMENT_SNAPSHOT_SIZE; j = j + 1) begin
                            if (paddr_low_bottom == (`ANIN_MEASUREMENT_SNAPSHOT_START_ADDR + ((i * (`ANIN_MEASUREMENT_SNAPSHOT_SIZE + `ANIN_MEASUREMENTS_SUM_SNAPSHOT_SIZE)) + j))) begin
                                sys_io_prdata <= anin_measurement_snapshot[i][DATA_BITS * j+:DATA_BITS];
                            end
                        end
                        for (j = 0; j < `ANIN_MEASUREMENTS_SUM_SNAPSHOT_SIZE; j = j + 1) begin
                            if (paddr_low_bottom == (`ANIN_MEASUREMENT_SNAPSHOT_START_ADDR + ((i * (`ANIN_MEASUREMENT_SNAPSHOT_SIZE + `ANIN_MEASUREMENTS_SUM_SNAPSHOT_SIZE)) + `ANIN_MEASUREMENT_SNAPSHOT_SIZE + j))) begin
                                sys_io_prdata <= anin_measurements_sum_snapshot[i][DATA_BITS * j+:DATA_BITS];
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
