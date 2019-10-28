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

module mbed_tester_peripherals_apb2_slave #(
        parameter IO_LOGICAL = 8
    )
    (
        input wire clk,
        input wire rst,

        input wire [IO_LOGICAL - 1:0] logical_in,
        output wire [IO_LOGICAL - 1:0] logical_val,
        output wire [IO_LOGICAL - 1:0] logical_drive,

        input wire [ADDR_BITS - 1:0] PADDR,
        input wire PSEL,
        input wire PENABLE,
        input wire PWRITE,
        input wire [DATA_BITS - 1:0] PWDATA,
        output wire [DATA_BITS - 1:0] PRDATA
    );

    localparam DATA_BITS = 8;
    localparam ADDR_BITS = 20;
    localparam ADDR_LOW_BITS = 12;
    localparam ADDR_HIGH_BITS = ADDR_BITS - ADDR_LOW_BITS;
    localparam PERIPHERALS = 8;

    wire [PERIPHERALS * DATA_BITS - 1:0] PRDATAs;
    wire [PERIPHERALS - 1:0] PSELs;

    wire [ADDR_LOW_BITS - 1:0] paddr_low;
    wire [ADDR_HIGH_BITS - 1:0] paddr_high;

    wire [IO_LOGICAL - 1:0] logical_val_peripherals [0:PERIPHERALS - 1];
    wire [IO_LOGICAL - 1:0] logical_drive_peripherals [0:PERIPHERALS - 1];

    wire config_psel;
    reg [DATA_BITS - 1:0] config_prdata;
    reg [8 - 1:0] current_peripheral;

    wire gpio_psel;
    reg [DATA_BITS - 1:0] gpio_prdata;
    reg [IO_LOGICAL - 1:0] gpio_val;
    reg [IO_LOGICAL - 1:0] gpio_drive;

    wire spi_master_psel;
    wire [DATA_BITS - 1:0] spi_master_prdata;
    wire [IO_LOGICAL - 1:0] spi_master_val;
    wire [IO_LOGICAL - 1:0] spi_master_drive;

    wire io_metrics_psel;
    wire [DATA_BITS - 1:0] io_metrics_prdata;
    wire [IO_LOGICAL - 1:0] io_metrics_val;
    wire [IO_LOGICAL - 1:0] io_metrics_drive;

    wire uart_psel;
    wire [DATA_BITS - 1:0] uart_prdata;
    wire [IO_LOGICAL - 1:0] uart_val;
    wire [IO_LOGICAL - 1:0] uart_drive;

    wire i2c_master_psel;
    wire [DATA_BITS - 1:0] i2c_master_prdata;
    wire [IO_LOGICAL - 1:0] i2c_master_val;
    wire [IO_LOGICAL - 1:0] i2c_master_drive;

    wire spi_slave_psel;
    wire [DATA_BITS - 1:0] spi_slave_prdata;
    wire [IO_LOGICAL - 1:0] spi_slave_val;
    wire [IO_LOGICAL - 1:0] spi_slave_drive;

    wire timer_psel;
    wire [DATA_BITS - 1:0] timer_prdata;
    wire [IO_LOGICAL - 1:0] timer_val;
    wire [IO_LOGICAL - 1:0] timer_drive;

    genvar i_gen;

    assign paddr_low = PADDR[ADDR_LOW_BITS - 1:0];
    assign paddr_high = PADDR[ADDR_LOW_BITS + ADDR_HIGH_BITS - 1:ADDR_LOW_BITS];

    assign config_psel = PSELs[0];      // 0x0000
    assign gpio_psel = PSELs[1];        // 0x1000
    assign spi_master_psel = PSELs[2];  // 0x2000
    assign io_metrics_psel = PSELs[3];  // 0x3000
    assign uart_psel = PSELs[4];        // 0x4000
    assign i2c_master_psel = PSELs[5];  // 0x5000
    assign spi_slave_psel = PSELs[6];   // 0x6000
    assign timer_psel = PSELs[7];       // 0x7000

    assign PRDATAs[0 * DATA_BITS+:DATA_BITS] = config_prdata;
    assign PRDATAs[1 * DATA_BITS+:DATA_BITS] = gpio_prdata;
    assign PRDATAs[2 * DATA_BITS+:DATA_BITS] = spi_master_prdata;
    assign PRDATAs[3 * DATA_BITS+:DATA_BITS] = io_metrics_prdata;
    assign PRDATAs[4 * DATA_BITS+:DATA_BITS] = uart_prdata;
    assign PRDATAs[5 * DATA_BITS+:DATA_BITS] = i2c_master_prdata;
    assign PRDATAs[6 * DATA_BITS+:DATA_BITS] = spi_slave_prdata;
    assign PRDATAs[7 * DATA_BITS+:DATA_BITS] = timer_prdata;

    assign logical_val_peripherals[0] = 0;
    assign logical_val_peripherals[1] = gpio_val;
    assign logical_val_peripherals[2] = spi_master_val;
    assign logical_val_peripherals[3] = io_metrics_val;
    assign logical_val_peripherals[4] = uart_val;
    assign logical_val_peripherals[5] = i2c_master_val;
    assign logical_val_peripherals[6] = spi_slave_val;
    assign logical_val_peripherals[7] = timer_val;

    assign logical_drive_peripherals[0] = 0;
    assign logical_drive_peripherals[1] = gpio_drive;
    assign logical_drive_peripherals[2] = spi_master_drive;
    assign logical_drive_peripherals[3] = io_metrics_drive;
    assign logical_drive_peripherals[4] = uart_drive;
    assign logical_drive_peripherals[5] = i2c_master_drive;
    assign logical_drive_peripherals[6] = spi_slave_drive;
    assign logical_drive_peripherals[7] = timer_drive;

    slave_mux_apb2_slave #(.SELECTOR_BITS(ADDR_HIGH_BITS), .DATA_BITS(DATA_BITS), .SLAVES(PERIPHERALS)) slave_mux_apb2_slave(
        .select(paddr_high),
        .PSEL(PSEL),
        .PRDATA(PRDATA),
        .PSELs(PSELs),
        .PRDATAs(PRDATAs)
    );

    /* Map the active peripheral to the mux */
    assign logical_val = current_peripheral < PERIPHERALS ? logical_val_peripherals[current_peripheral] : 0;
    assign logical_drive = current_peripheral < PERIPHERALS ? logical_drive_peripherals[current_peripheral] : 0;

    // Config - Offset 0x0000
    always @(posedge clk) begin
        if (rst) begin
            current_peripheral <= 0;
            config_prdata <= 0;
        end begin
            if (config_psel) begin
                if (PWRITE && PENABLE) begin
                    case (paddr_low)
                        // Peripheral select
                        0: current_peripheral <= PWDATA;
                        default:;
                    endcase
                end
                if (!PWRITE) begin
                    case (paddr_low)
                        0:  config_prdata <= current_peripheral;
                        default: config_prdata <= 0;
                    endcase
                end
            end
        end
    end

    // GPIO - Offset 0x1000
    always @(posedge clk) begin
        if (rst) begin
            gpio_val <= 0;
            gpio_drive <= 0;
            gpio_prdata <= 0;
        end begin
            if (gpio_psel) begin
                if (PWRITE && PENABLE) begin
                    if (paddr_low < IO_LOGICAL) begin
                        // Write to GPIO
                        gpio_val[paddr_low] <= PWDATA[0];
                        gpio_drive[paddr_low] <= PWDATA[1];
                    end
                end
                if (!PWRITE) begin
                    if (paddr_low < IO_LOGICAL) begin
                        // Read from GPIO
                        gpio_prdata <= logical_in[paddr_low];
                    end else begin
                        gpio_prdata <= 0;
                    end
                end
            end
        end
    end

    // SPI master - Offset 0x2000
    spi_master_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) spi_master_tester_apb2_slave (
        clk,
        rst,
        logical_in,
        spi_master_val,
        spi_master_drive,
        paddr_low,
        spi_master_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        spi_master_prdata
        );

    // IO metrics - Offset 0x3000
    io_metrics_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) io_metrics_apb2_slave (
        clk,
        rst,
        logical_in,
        io_metrics_val,
        io_metrics_drive,
        paddr_low,
        io_metrics_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        io_metrics_prdata
    );

    // UART Tester - Offset 0x4000
    uart_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) uart_tester_apb2_slave (
        clk,
        rst,
        logical_in,
        uart_val,
        uart_drive,
        paddr_low,
        uart_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        uart_prdata
    );

    // I2C master - Offset 0x5000
    i2c_master_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) i2c_master_tester_apb2_slave (
        clk,
        rst,
        logical_in,
        i2c_master_val,
        i2c_master_drive,
        paddr_low,
        i2c_master_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        i2c_master_prdata
    );

    // SPI slave - Offset 0x6000
    spi_slave_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) spi_slave_tester_apb2_slave (
        clk,
        rst,
        logical_in,
        spi_slave_val,
        spi_slave_drive,
        paddr_low,
        spi_slave_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        spi_slave_prdata
        );

    // Timer - Offset 0x7000
    timer_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) timer_apb2_slave (
        clk,
        rst,
        logical_in,
        timer_val,
        timer_drive,
        paddr_low,
        timer_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        timer_prdata
        );

endmodule
