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

module uart_tester_apb2_slave_tb;
    parameter ADDR_BITS = 12;
    parameter DATA_BITS = 8;
    parameter IO_LOGICAL = 8;

    localparam UART_CONTROL                     = 'h000;
    localparam UART_CONTROL_SIZE                = 4;
    localparam UART_BAUD_DIVISOR                = 'h004;
    localparam UART_BAUD_DIVISOR_SIZE           = 2;
    localparam UART_BIT_COUNT                   = 'h010;
    localparam UART_BIT_COUNT_SIZE              = 1;
    localparam UART_STOP_COUNT                  = 'h011;
    localparam UART_STOP_COUNT_SIZE             = 1;
    localparam UART_PARITY                      = 'h012;
    localparam UART_PARITY_SIZE                 = 1;
    localparam UART_PARITY_ENABLE               = (1 << 0);
    localparam UART_PARITY_ODD_N_EVEN           = (1 << 1);
    localparam UART_RX_CONTROL                  = 'h100;
    localparam UART_RX_CONTROL_SIZE             = 4;
    localparam UART_RX_CONTROL_ENABLE           = (1 << 0);
    localparam UART_RX_CONTROL_RESET            = (1 << 1);
    localparam UART_RX_CHECKSUM                 = 'h104;
    localparam UART_RX_CHECKSUM_SIZE            = 4;
    localparam UART_RX_COUNT                    = 'h108;
    localparam UART_RX_COUNT_SIZE               = 4;
    localparam UART_RX_PARITY_ERRORS            = 'h10C;
    localparam UART_RX_PARITY_ERRORS_SIZE       = 4;
    localparam UART_RX_STOP_ERRORS              = 'h110;
    localparam UART_RX_STOP_ERRORS_SIZE         = 4;
    localparam UART_RX_FRAMING_ERRORS           = 'h114;
    localparam UART_RX_FRAMING_ERRORS_SIZE      = 4;
    localparam UART_RX_PREV_4                   = 'h118;
    localparam UART_RX_PREV_4_SIZE              = 2;
    localparam UART_RX_PREV_3                   = 'h11A;
    localparam UART_RX_PREV_3_SIZE              = 2;
    localparam UART_RX_PREV_2                   = 'h11C;
    localparam UART_RX_PREV_2_SIZE              = 2;
    localparam UART_RX_PREV_1                   = 'h11E;
    localparam UART_RX_PREV_1_SIZE              = 2;
    localparam UART_TX_CONTROL                  = 'h200;
    localparam UART_TX_CONTROL_SIZE             = 4;
    localparam UART_TX_CONTROL_ENABLE           = (1 << 0);
    localparam UART_TX_CONTROL_RESET            = (1 << 1);
    localparam UART_TX_CONTROL_ENABLE_CTS       = (1 << 2);
    localparam UART_TX_COUNT                    = 'h204;
    localparam UART_TX_COUNT_SIZE               = 4;
    localparam UART_TX_NEXT                     = 'h208;
    localparam UART_TX_NEXT_SIZE                = 2;
    localparam UART_CTS_DEACTIVATE_DELAY        = 'h210;
    localparam UART_CTS_DEACTIVATE_DELAY_SIZE   = 4;
    localparam UART_TX_DELAY                    = 'h214;
    localparam UART_TX_DELAY_SIZE               = 4;

    reg clk, rst;

    integer i;

    wire [ADDR_BITS - 1:0] PADDR;
    wire PSEL;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] PRDATA;

    wire [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] logical_val;
    wire [IO_LOGICAL - 1:0] logical_drive;

    wire dut_tx;
    wire dut_rx;
    reg dut_cts;
    wire dut_rts;

    signal_history dut_cts_history(
        .clk(clk),
        .signal(dut_cts)
    );

    signal_history cts_delayed_history(
        .clk(clk),
        .signal(uart_tester_apb2_slave.cts_delayed)
    );

    signal_history tx_enable_history(
        .clk(clk),
        .signal(uart_tester_apb2_slave.tx_enable)
    );

    signal_history tx_send_history(
        .clk(clk),
        .signal(uart_tester_apb2_slave.tx_send)
    );

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA)
    );

    uart_tester uart_tester(
        .clk(clk),
        .rst(rst),
        .tx(dut_rx),
        .rx(dut_tx)
    );

    uart_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) uart_tester_apb2_slave (
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

    assign dut_tx = logical_val[0];
    assign logical_in[1] = dut_rx;
    assign logical_in[2] = dut_cts;
    assign dut_rts = logical_val[3];

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

    task normal_operation_testcase;
        reg [31:0] data4;
        reg [15:0] data2;
        reg [7:0] data;
        integer i;
        integer j;

        integer period;
        reg [15:0] div;
        reg parity_enable;
        reg parity_odd_n_even;
        reg [3:0] bit_count;
        reg [3:0] stop_count;
        reg [15:0] send_data;

        reg [15:0] send_data_history[0:7];
        integer checksum;
        integer transfers;

        begin
            reset(20);
            dut_cts = 1;

            // Check initial values

            apb2_slave_tester.read4le(UART_CONTROL, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_BAUD_DIVISOR, data2);
            `util_assert_equal(16'hFFFF, data2);
            apb2_slave_tester.read2le(UART_BIT_COUNT, data);
            `util_assert_equal(8, data);
            apb2_slave_tester.read2le(UART_STOP_COUNT, data);
            `util_assert_equal(1, data);
            apb2_slave_tester.read2le(UART_PARITY, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read4le(UART_RX_CONTROL, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_CHECKSUM, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_COUNT, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_RX_PREV_4, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_3, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_2, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_1, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read4le(UART_TX_CONTROL, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_TX_COUNT, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_TX_NEXT, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read4le(UART_CTS_DEACTIVATE_DELAY, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_TX_DELAY, data4);
            `util_assert_equal(0, data4);

            // Set values

            period = 100;
            div = period / 10;
            parity_enable = 1;
            parity_odd_n_even = 1;
            bit_count = 15;
            stop_count = 4;

            uart_tester.set_period(period);
            uart_tester.set_parity(parity_enable, parity_odd_n_even);
            uart_tester.set_data_bits(bit_count);
            uart_tester.set_stop_bits(stop_count);

            apb2_slave_tester.write2le(UART_BAUD_DIVISOR, div);
            apb2_slave_tester.write(UART_BIT_COUNT, bit_count);
            apb2_slave_tester.write(UART_STOP_COUNT, stop_count);
            apb2_slave_tester.write(UART_PARITY, (parity_enable ? UART_PARITY_ENABLE : 0) | (parity_odd_n_even ? UART_PARITY_ODD_N_EVEN : 0));

            // Send data and verify nothing happens

            send_data = {$random} % 'h8000;
            uart_tester.send(send_data);

            #1000

            apb2_slave_tester.read4le(UART_RX_CHECKSUM, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_COUNT, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(0, data4);

            // Enable RX, Send 8 bytes to DUT and verify count, checksum, last 4

            apb2_slave_tester.write4le(UART_RX_CONTROL, UART_RX_CONTROL_ENABLE);

            checksum = 0;
            transfers = 8;
            for (i = 0; i < transfers; i = i + 1) begin
                send_data = {$random} % 'h8000;
                checksum = checksum + send_data;
                send_data_history[i] = send_data;
                uart_tester.send(send_data);
            end

            #1000

            apb2_slave_tester.read4le(UART_RX_CHECKSUM, data4);
            `util_assert_equal(checksum, data4);
            apb2_slave_tester.read4le(UART_RX_COUNT, data4);
            `util_assert_equal(8, data4);
            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_RX_PREV_4, data2);
            `util_assert_equal(send_data_history[transfers - 4], data2);
            apb2_slave_tester.read2le(UART_RX_PREV_3, data2);
            `util_assert_equal(send_data_history[transfers - 3], data2);
            apb2_slave_tester.read2le(UART_RX_PREV_2, data2);
            `util_assert_equal(send_data_history[transfers - 2], data2);
            apb2_slave_tester.read2le(UART_RX_PREV_1, data2);
            `util_assert_equal(send_data_history[transfers - 1], data2);

            // Bad start

            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(0, data4);

            uart_tester.send_pulse(period / 4);

            #1000

            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(1, data4);

            // Bad parity

            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(0, data4);

            transfers = 4;
            uart_tester.set_parity(parity_enable, !parity_odd_n_even);
            for (i = 0; i < transfers; i = i + 1) begin
                send_data = {$random} % 'h8000;
                uart_tester.send(send_data);
            end

            #1000

            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(transfers, data4);
            uart_tester.set_parity(parity_enable, parity_odd_n_even);

            // bad stop

            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert_equal(0, data4);

            transfers = 2;
            uart_tester.set_stop_bits(stop_count - 1);
            for (i = 0; i < transfers; i = i + 1) begin
                uart_tester.send(0);
            end


            #1000

            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert(data4 >= 1);
            uart_tester.set_stop_bits(stop_count);

            // Reset receiver

            apb2_slave_tester.write4le(UART_RX_CONTROL, UART_RX_CONTROL_RESET);
            apb2_slave_tester.read4le(UART_RX_CONTROL, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_CHECKSUM, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_COUNT, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_PARITY_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_STOP_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read4le(UART_RX_FRAMING_ERRORS, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_RX_PREV_4, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_3, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_2, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read2le(UART_RX_PREV_1, data2);
            `util_assert_equal(0, data2);

            // Read 8 bytes from DUT and verify the bytes were expected

            send_data = 1234;
            transfers = 8;
            apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
            apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
            uart_tester.receive_start();
            apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE);

            #(1000 + transfers * period * (1 + bit_count + 1 + stop_count));

            uart_tester.receive_stop();
            `util_assert_equal(transfers, uart_tester.receive_count);
            for (i = 0; i < transfers; i = i + 1) begin
                `util_assert_equal(1, uart_tester.receive_value_valid(i));
                `util_assert_equal(send_data + i, uart_tester.receive_value(i));
            end

            apb2_slave_tester.write4le(UART_TX_CONTROL, 0);

            // Enable flow control and but leave CTS de-asserted

            @(negedge clk);
            dut_cts = 1;
            for (i = 0; i < 2; i = i + 1) begin
                send_data = 1234;
                transfers = 8;
                apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
                apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
                apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, i == 0 ? 'hffff : 0 );
                uart_tester.receive_start();
                apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE | UART_TX_CONTROL_ENABLE_CTS);

                #(1000 + transfers * period * (1 + bit_count + 1 + stop_count));

                uart_tester.receive_stop();
                `util_assert_equal(0, uart_tester.receive_count);
                apb2_slave_tester.write4le(UART_TX_CONTROL, 0);
            end

            // Enable flow control and assert CTS

            @(negedge clk);
            dut_cts = 0;
            for (i = 0; i < 2; i = i + 1) begin
                send_data = 1234;
                transfers = 8;
                apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
                apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
                apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, i == 0 ? 10 : 0 );
                uart_tester.receive_start();
                apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE | UART_TX_CONTROL_ENABLE_CTS);

                #(1000 + transfers * period * (1 + bit_count + 1 + stop_count));

                uart_tester.receive_stop();
                `util_assert_equal(transfers, uart_tester.receive_count);
                for (j = 0; j < transfers; j = j + 1) begin
                    `util_assert_equal(1, uart_tester.receive_value_valid(j));
                    `util_assert_equal(send_data + j, uart_tester.receive_value(j));
                end
                apb2_slave_tester.write4le(UART_TX_CONTROL, 0);
            end

            // Reset transmitter

            send_data = 1234;
            transfers = 8;
            apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
            apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
            apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, 'h1234);

            apb2_slave_tester.read4le(UART_TX_COUNT, data4);
            `util_assert_equal(transfers, data4);
            apb2_slave_tester.read2le(UART_TX_NEXT, data2);
            `util_assert_equal(send_data, data2);

            apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_RESET);

            apb2_slave_tester.read4le(UART_TX_COUNT, data4);
            `util_assert_equal(0, data4);
            apb2_slave_tester.read2le(UART_TX_NEXT, data2);
            `util_assert_equal(0, data2);
            apb2_slave_tester.read4le(UART_CTS_DEACTIVATE_DELAY, data4);
            `util_assert_equal(0, data4);
        end
    endtask

    task cts_delay_timing_testcase;
        integer cts_delay;
        integer clk_period;
        integer i;

        begin
            clk_period = 10;

            /*
             * Given the CTS sequence and CTS_DEACTIVATE_DELAY ensure delay cts is correct:
             *
             *
             *      1                  ---------------
             * cts
             *      0   ---------------               -------------------------
             *
             *
             *      1                       ----------
             * delayed cts
             *      0   --------------------          -------------------------
             *
             * cts_delay               |---|
             *
             */
            reset(20);
            @(negedge clk);
            dut_cts = 0;
            cts_delay = 5;
            apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, cts_delay);
            apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE | UART_TX_CONTROL_ENABLE_CTS);
            dut_cts_history.reset();
            cts_delayed_history.reset();

            @(negedge clk);

            #(clk_period * 15);

            dut_cts = 1;
            #(clk_period * 15);

            dut_cts = 0;

            #(clk_period * 25);

            // Sanity check test signal
            `util_assert_equal(2, dut_cts_history.events);
            `util_assert_equal(1, dut_cts_history.get_value(0));
            `util_assert_equal(0, dut_cts_history.get_value(1));
            `util_assert_equal(dut_cts_history.get_cycle(0) + 15, dut_cts_history.get_cycle(1));

            // Check real signal
            `util_assert_equal(2, cts_delayed_history.events);
            `util_assert_equal(1, cts_delayed_history.get_value(0));
            `util_assert_equal(0, cts_delayed_history.get_value(1));
            `util_assert_equal(dut_cts_history.get_cycle(0) + cts_delay, cts_delayed_history.get_cycle(0));
            `util_assert_equal(dut_cts_history.get_cycle(1), cts_delayed_history.get_cycle(1));

            /*
             * Given that CTS is high for less than or equal to CTS_DEACTIVATE_DELAY verify that delay cts is always low:
             *
             *
             *      1                  ---------------     -
             * cts
             *      0   ---------------               ----- -------------------
             *
             *
             *      1
             * delayed cts
             *      0   -------------------------------------------------------
             *
             * CTS_DEACTIVATE_DELAY    |-------------|
             *
             */
            reset(20);
            @(negedge clk);
            dut_cts = 0;
            cts_delay = 15;
            apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, cts_delay);
            apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE | UART_TX_CONTROL_ENABLE_CTS);
            dut_cts_history.reset();
            cts_delayed_history.reset();

            @(negedge clk);

            #(clk_period * 15);

            dut_cts = 1;
            #(clk_period * 15);

            dut_cts = 0;
            #(clk_period * 5);

            dut_cts = 1;
            #(clk_period * 1);

            dut_cts = 0;
            #(clk_period * 19);

            // Sanity check test signal
            `util_assert_equal(4, dut_cts_history.events);
            `util_assert_equal(1, dut_cts_history.get_value(0));
            `util_assert_equal(0, dut_cts_history.get_value(1));
            `util_assert_equal(1, dut_cts_history.get_value(2));
            `util_assert_equal(0, dut_cts_history.get_value(3));
            `util_assert_equal(dut_cts_history.get_cycle(0) + 15, dut_cts_history.get_cycle(1));
            `util_assert_equal(dut_cts_history.get_cycle(1) + 5, dut_cts_history.get_cycle(2));
            `util_assert_equal(dut_cts_history.get_cycle(2) + 1, dut_cts_history.get_cycle(3));

            // Check real signal
            `util_assert_equal(0, uart_tester_apb2_slave.cts_delayed);
            `util_assert_equal(0, cts_delayed_history.events);

            /*
             * Given that CTS_DEACTIVATE_DELAY = 0 verify that cts delay is identical to delayed cts:
             *
             *
             *      1                  ---------------     -
             * cts
             *      0   ---------------               ----- --------------------
             *
             *
             *      1                  ---------------     -
             * delayed cts
             *      0   ---------------               ----- --------------------
             *
             * CTS_DEACTIVATE_DELAY=0
             *
             */
            reset(20);
            @(negedge clk);
            dut_cts = 0;
            cts_delay = 0;
            apb2_slave_tester.write4le(UART_CTS_DEACTIVATE_DELAY, cts_delay);
            apb2_slave_tester.write4le(UART_TX_CONTROL, UART_TX_CONTROL_ENABLE | UART_TX_CONTROL_ENABLE_CTS);
            dut_cts_history.reset();
            cts_delayed_history.reset();

            @(negedge clk);

            #(clk_period * 15);

            dut_cts = 1;
            #(clk_period * 15);

            dut_cts = 0;
            #(clk_period * 5);

            dut_cts = 1;
            #(clk_period * 1);

            dut_cts = 0;
            #(clk_period * 19);

            // Sanity check test signal
            `util_assert_equal(4, dut_cts_history.events);
            `util_assert_equal(1, dut_cts_history.get_value(0));
            `util_assert_equal(0, dut_cts_history.get_value(1));
            `util_assert_equal(1, dut_cts_history.get_value(2));
            `util_assert_equal(0, dut_cts_history.get_value(3));
            `util_assert_equal(dut_cts_history.get_cycle(0) + 15, dut_cts_history.get_cycle(1));
            `util_assert_equal(dut_cts_history.get_cycle(1) + 5, dut_cts_history.get_cycle(2));
            `util_assert_equal(dut_cts_history.get_cycle(2) + 1, dut_cts_history.get_cycle(3));

            // Check real signal
            `util_assert_equal(4, cts_delayed_history.events);
            for (i = 0; i < 4; i = i + 1) begin
                `util_assert_equal(dut_cts_history.get_cycle(0), cts_delayed_history.get_cycle(0));
                `util_assert_equal(dut_cts_history.get_value(0), cts_delayed_history.get_value(0));
            end

        end
    endtask

    task tx_delay_timing_testcase;
        integer tx_delay;
        integer clk_period;
        reg [15:0] send_data;
        integer transfers;
        integer i;

        begin
            clk_period = 10;

            /*
             * Given the TX_ENABLE sequence and TX_DELAY ensure delayed TX_SEND is correct:
             *
             *
             *      1                  ---------------
             * tx_enable
             *      0   ---------------               -------------------------
             *
             *
             *      1                       ----------
             * delayed tx_send
             *      0   --------------------          -------------------------
             *
             * tx_delay                |---|
             *
             */
            reset(20);
            @(negedge clk);
            transfers = 8;
            send_data = 1234;
            tx_delay = 5;
            apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
            apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
            apb2_slave_tester.write4le(UART_TX_DELAY, tx_delay);
            tx_enable_history.reset();
            tx_send_history.reset();

            @(negedge clk);
            #(clk_period * 15);

            // Access the uart_tester_apb2_slave.tx_enable signal directly to avoid
            // transfer delays on the APB bus.
            uart_tester_apb2_slave.tx_enable = 1;
            #(clk_period * 15);

            uart_tester_apb2_slave.tx_enable = 0;
            #(clk_period * 25);

            // Sanity check test signal
            `util_assert_equal(2, tx_enable_history.events);
            `util_assert_equal(1, tx_enable_history.get_value(0));
            `util_assert_equal(0, tx_enable_history.get_value(1));
            `util_assert_equal(tx_enable_history.get_cycle(0) + 15, tx_enable_history.get_cycle(1));

            // Check real signal
            `util_assert_equal(2, tx_send_history.events);
            `util_assert_equal(1, tx_send_history.get_value(0));
            `util_assert_equal(0, tx_send_history.get_value(1));
            `util_assert_equal(tx_enable_history.get_cycle(0) + tx_delay, tx_send_history.get_cycle(0));
            `util_assert_equal(tx_enable_history.get_cycle(1), tx_send_history.get_cycle(1));

            /*
             * Given that TX_ENABLE is high for less than or equal to TX_DELAY
             * verify that delay TX_SEND is always low:
             *
             *
             *      1                  ---------------     -
             * tx_enable
             *      0   ---------------               ----- -------------------
             *
             *
             *      1
             * delayed tx_send
             *      0   -------------------------------------------------------
             *
             * tx_delay                |-------------|
             *
             */
            reset(20);
            @(negedge clk);
            transfers = 8;
            send_data = 1234;
            tx_delay = 15;
            apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
            apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
            apb2_slave_tester.write4le(UART_TX_DELAY, tx_delay);
            tx_enable_history.reset();
            tx_send_history.reset();

            @(negedge clk);
            #(clk_period * 15);

            // Access the uart_tester_apb2_slave.tx_enable signal directly to avoid
            // transfer delays on the APB bus.
            uart_tester_apb2_slave.tx_enable = 1;
            #(clk_period * 15);

            uart_tester_apb2_slave.tx_enable = 0;
            #(clk_period * 5);

            uart_tester_apb2_slave.tx_enable = 1;
            #(clk_period * 1);

            uart_tester_apb2_slave.tx_enable = 0;
            #(clk_period * 19);

            // Sanity check test signal
            `util_assert_equal(4, tx_enable_history.events);
            `util_assert_equal(1, tx_enable_history.get_value(0));
            `util_assert_equal(0, tx_enable_history.get_value(1));
            `util_assert_equal(1, tx_enable_history.get_value(2));
            `util_assert_equal(0, tx_enable_history.get_value(3));
            `util_assert_equal(tx_enable_history.get_cycle(0) + 15, tx_enable_history.get_cycle(1));
            `util_assert_equal(tx_enable_history.get_cycle(1) + 5, tx_enable_history.get_cycle(2));
            `util_assert_equal(tx_enable_history.get_cycle(2) + 1, tx_enable_history.get_cycle(3));

            // Check real signal
            `util_assert_equal(0, tx_send_history.events);

            /*
             * Given that TX_DELAY = 0 verify that TX_SEND is identical to TX_ENABLE:
             *
             *
             *      1                  ---------------     -
             * tx_enable
             *      0   ---------------               ----- --------------------
             *
             *
             *      1                  ---------------     -
             * delayed tx_send
             *      0   ---------------               ----- --------------------
             *
             * tx_delay=0
             *
             */
            reset(20);
            @(negedge clk);
            transfers = 8;
            send_data = 1234;
            tx_delay = 0;
            apb2_slave_tester.write4le(UART_TX_COUNT, transfers);
            apb2_slave_tester.write2le(UART_TX_NEXT, send_data);
            apb2_slave_tester.write4le(UART_TX_DELAY, tx_delay);
            tx_enable_history.reset();
            tx_send_history.reset();

            @(negedge clk);
            #(clk_period * 15);

            // Access the uart_tester_apb2_slave.tx_enable signal directly to avoid
            // transfer delays on the APB bus.
            uart_tester_apb2_slave.tx_enable = 1;
            #(clk_period * 15);

            uart_tester_apb2_slave.tx_enable = 0;
            #(clk_period * 5);

            uart_tester_apb2_slave.tx_enable = 1;
            #(clk_period * 1);

            uart_tester_apb2_slave.tx_enable = 0;
            #(clk_period * 19);

            // Sanity check test signal
            `util_assert_equal(4, tx_enable_history.events);
            `util_assert_equal(1, tx_enable_history.get_value(0));
            `util_assert_equal(0, tx_enable_history.get_value(1));
            `util_assert_equal(1, tx_enable_history.get_value(2));
            `util_assert_equal(0, tx_enable_history.get_value(3));
            `util_assert_equal(tx_enable_history.get_cycle(0) + 15, tx_enable_history.get_cycle(1));
            `util_assert_equal(tx_enable_history.get_cycle(1) + 5, tx_enable_history.get_cycle(2));
            `util_assert_equal(tx_enable_history.get_cycle(2) + 1, tx_enable_history.get_cycle(3));

            // Check real signal
            `util_assert_equal(4, tx_send_history.events);
            for (i = 0; i < 4; i = i + 1) begin
                `util_assert_equal(tx_enable_history.get_cycle(0), tx_send_history.get_cycle(0));
                `util_assert_equal(tx_enable_history.get_value(0), tx_send_history.get_value(0));
            end

        end
    endtask
    initial begin
        normal_operation_testcase();
        cts_delay_timing_testcase();
        tx_delay_timing_testcase();
        -> terminate_sim;
    end

endmodule
