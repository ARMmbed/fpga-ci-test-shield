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

module io_metrics_apb2_slave_tb;
    parameter ADDR_BITS = 12;
    parameter DATA_BITS = 8;
    parameter IO_LOGICAL = 4;

    localparam IDLE_CYCLES = 100;

    localparam CONTROL_ADDR = 0;
    localparam BANK_SIZE = 64;
    localparam METRIC_BASE_ADDR = 64;
    localparam MIN_PULSE_LOW_OFFSET = 0;
    localparam MIN_PULSE_HIGH_OFFSET = 4;
    localparam MAX_PULSE_LOW_OFFSET = 8;
    localparam MAX_PULSE_HIGH_OFFSET = 12;
    localparam RISING_EDGES_OFFSET = 16;
    localparam FALLIG_EDGES_OFFSET = 20;

    reg clk, rst;

    integer i;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    reg [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] logical_val;
    wire [IO_LOGICAL - 1:0] logical_drive;

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    io_metrics_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) io_metrics_apb2_slave(
        .clk(clk),
        .rst(rst),
        .logical_in(logical_in),
        .logical_val(logical_val),
        .logical_drive(logical_drive),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
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
        logical_in = 0;
    end

    task reset;
        input integer reset_time;
        begin
            @(negedge clk);
            rst = 1;
            logical_in = 0;
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

    task wait_clks;
        input integer clks;
        begin
            // Assert we are on a negative clock edge
            `util_assert_equal(0, $time % 10);
            #(clks * 10);
        end
    endtask

    task normal_operation_testcase;
        reg [31:0] data;

        integer high_pulse_short;
        integer high_pulse_long;
        integer low_pulse;
        integer rising;
        integer falling;
        integer i;
        reg [ADDR_BITS - 1:0] base;
        begin
            reset(20);

            /* Check initial values
             */

            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(0, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
            end
            @(negedge clk);

            /* Send pulses with metrics off and verify the metrics don't change
             */

            // 10 clocks low
            wait_clks(IDLE_CYCLES);

            // 10 clocks high
            logical_in = 4'hF;
            wait_clks(10);

            // 10 clocks low
            logical_in = 4'h0;
            wait_clks(IDLE_CYCLES);

            // Check values
            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(0, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
            end
            @(negedge clk);

            /* Enable metrics, set initial pulse values and check them
             */

            // Enable metrics
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);
            high_pulse_short = 17;
            high_pulse_long = 20;
            low_pulse = 27;
            rising = 0;
            falling = 0;

            // low
            wait_clks(IDLE_CYCLES);

            // high
            logical_in = 4'hF;
            rising =  rising + 1;
            wait_clks(high_pulse_short);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(low_pulse);

            // high
            logical_in = 4'hF;
            rising = rising + 1;
            wait_clks(high_pulse_long);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(IDLE_CYCLES);

            // Check values
            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(1, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(low_pulse, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_short, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert(data >= IDLE_CYCLES);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_long, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(rising, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(falling, data);
            end
            @(negedge clk);

            /* Generate pulses which should not effect the previous values
             * and check that the previous value stays
             */

            // low
            wait_clks(IDLE_CYCLES);

            // high
            logical_in = 4'hF;
            rising = rising + 1;
            wait_clks(high_pulse_short + 1);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(low_pulse + 1);

            // high
            logical_in = 4'hF;
            rising = rising + 1;
            wait_clks(high_pulse_long - 1);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(IDLE_CYCLES);

            // Check values
            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(1, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(low_pulse, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_short, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert(data >= IDLE_CYCLES);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_long, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(rising, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(falling, data);
            end
            @(negedge clk);

            /* Generate pulses which should effect the previous values
             * and check that the values are updated
             */

            high_pulse_short = high_pulse_short - 1;
            low_pulse = low_pulse - 1;
            high_pulse_long = high_pulse_long + 1;

            // low
            wait_clks(IDLE_CYCLES);

            // high
            logical_in = 4'hF;
            rising = rising + 1;
            wait_clks(high_pulse_short);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(low_pulse);

            // high
            logical_in = 4'hF;
            rising = rising + 1;
            wait_clks(high_pulse_long);

            // low
            logical_in = 4'h0;
            falling = falling + 1;
            wait_clks(IDLE_CYCLES);

            // Check values
            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(1, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(low_pulse, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_short, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert(data >= IDLE_CYCLES);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_long, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(rising, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(falling, data);
            end
            @(negedge clk);

            /* Disable recording and generate pulses which should effect
             * the previous values w(hen recording) and check that the
             * values do not change
             *
             */

            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            // low
            wait_clks(IDLE_CYCLES);

            // high
            logical_in = 4'hF;
            wait_clks(high_pulse_short - 1);

            // low
            logical_in = 4'h0;
            wait_clks(low_pulse - 1);

            // high
            logical_in = 4'hF;
            wait_clks(high_pulse_long + 1);

            // low
            logical_in = 4'h0;
            wait_clks(IDLE_CYCLES);

            // Check values
            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(0, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(low_pulse, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_short, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert(data >= IDLE_CYCLES);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(high_pulse_long, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(rising, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(falling, data);
            end
            @(negedge clk);

            /* Reset and check that values are reset accordingly
             */

            apb2_slave_tester.write(CONTROL_ADDR, 2);
            @(negedge clk);
            wait_clks(2);

            apb2_slave_tester.read4le(CONTROL_ADDR, data);
            `util_assert_equal(0, data);
            for (i = 0; i < IO_LOGICAL; i = i + 1) begin
                base = METRIC_BASE_ADDR + BANK_SIZE * i;
                apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(32'hffffffff, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
                apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
                `util_assert_equal(0, data);
            end
            @(negedge clk);
        end
    endtask

    task edge_case_testcase;
        reg [31:0] data;

        integer delay_start;
        integer delay_middle;
        integer delay_end;
        integer activate_overhead;
        integer deactivate_overhead;
        time start_time;
        time end_time;

        integer i;
        reg [ADDR_BITS - 1:0] base;
        begin
            delay_start = 20;
            delay_middle = 5;
            delay_end = 30;
            activate_overhead = 1;
            deactivate_overhead = 1;
            base = METRIC_BASE_ADDR;

            /* Check low with no transition
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1    |                         |
             *                      |                         |
             *                 0 ---+-------------------------+---
             *                      |                         |
             *
             * - min pulse low = 0xFFFFFFFF
             * - min pulse high = 0xFFFFFFFF
             * - max pulse low:     |-------------------------|
             * - max pulse high = 0x00000000
             * - rising edges = 0
             * - falling edges = 0
             */

            reset(20);

             // Inital value low
            @(negedge clk);
            logical_in = 0;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_start + activate_overhead + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(0, data);

            /* Check high with no transition
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1 ---+-------------------------+---
             *                      |                         |
             *                 0    |                         |
             *                      |                         |
             *
             * - min pulse low = 0xFFFFFFFF
             * - min pulse high = 0xFFFFFFFF
             * - max pulse low = 0x00000000
             * - max pulse high:    |-------------------------|
             * - rising edges = 0
             * - falling edges = 0
             *
             */

            reset(20);

            // Inital value high
            @(negedge clk);
            logical_in = 1;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_start + activate_overhead + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(0, data);

            /* Check low to high transition
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1    |          +--------------+---
             *                      |          |              |
             *                 0 ---+----------+              |
             *                      |                         |
             *
             * - min pulse low = 0xFFFFFFFF
             * - min pulse high = 0xFFFFFFFF
             * - max pulse low:     |----------|
             * - max pulse high:               |--------------|
             * - rising edges = 1
             * - falling edges = 0
             *
             */

            reset(20);

            // Inital value low
            @(negedge clk);
            logical_in = 0;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);
            logical_in = 1;

            wait_clks(delay_end);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_start + activate_overhead, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_end + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(1, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(0, data);

            /* Check high to low transition
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1 ---+----------+              |
             *                      |          |              |
             *                 0    |          +--------------+---
             *                      |                         |
             *
             * - min pulse low = 0xFFFFFFFF
             * - min pulse high = 0xFFFFFFFF
             * - max pulse low:                |--------------|
             * - max pulse high:    |----------|
             * - rising edges = 0
             * - falling edges = 1
             *
             */

            reset(20);

            // Inital value high
            @(negedge clk);
            logical_in = 1;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);
            logical_in = 0;

            wait_clks(delay_end);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_end + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_start + activate_overhead, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(1, data);

            /* Check high pulse timing
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1    |      +---+              |
             *                      |      |   |              |
             *                 0 ---+------+   +--------------+---
             *                      |                         |
             *
             * - min pulse low = 0xFFFFFFFF
             * - min pulse high:           |---|
             * - max pulse low:                |--------------|
             * - max pulse high:           |---|
             * - rising edges = 1
             * - falling edges = 1
             *
             */

            reset(20);

            // Inital value low
            @(negedge clk);
            logical_in = 0;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);
            logical_in = 1;

            wait_clks(delay_middle);
            logical_in = 0;

            wait_clks(delay_end);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_middle, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_end + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_middle, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(1, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(1, data);

            /* Check low pulse timing
             *
             *                    active=1                  active=0
             *                      |                         |
             *                 1 ---+------+   +--------------+---
             *                      |      |   |              |
             *                 0    |      +---+              |
             *                      |                         |
             *
             * - min pulse low:            |---|
             * - min pulse high = 0xFFFFFFFF
             * - max pulse low:            |---|
             * - max pulse high:               |--------------|
             * - rising edges = 1
             * - falling edges = 1
             *
             */

            reset(20);

            // Inital value high
            @(negedge clk);
            logical_in = 1;

            // Active = 1
            apb2_slave_tester.write(CONTROL_ADDR, 1);
            @(negedge clk);

            wait_clks(delay_start);
            logical_in = 0;

            wait_clks(delay_middle);
            logical_in = 1;

            wait_clks(delay_end);

            // Active = 0
            apb2_slave_tester.write(CONTROL_ADDR, 0);
            @(negedge clk);

            apb2_slave_tester.read4le(base + MIN_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_middle, data);
            apb2_slave_tester.read4le(base + MIN_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(32'hffffffff, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_LOW_OFFSET, data);
            `util_assert_equal(delay_middle, data);
            apb2_slave_tester.read4le(base + MAX_PULSE_HIGH_OFFSET, data);
            `util_assert_equal(delay_end + deactivate_overhead, data);
            apb2_slave_tester.read4le(base + RISING_EDGES_OFFSET, data);
            `util_assert_equal(1, data);
            apb2_slave_tester.read4le(base + FALLIG_EDGES_OFFSET, data);
            `util_assert_equal(1, data);
        end
    endtask

    initial begin
        normal_operation_testcase();
        edge_case_testcase();
        -> terminate_sim;
    end

endmodule
