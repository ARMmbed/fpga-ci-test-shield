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
`define CLK_CYCLE 10   //10 ticks per clk cycle
`define SCL100KHz 1000 //1000 clk cycles in one scl cycle when scl set to 100000Hz
`define SCL400KHz 250  //250 clk cycles in one scl cycle when scl set to 400000Hz
`define SCL1MHz   100  //100 clk cycles in one scl cycle when scl set to 1000000Hz

module i2c_master_tester_apb2_slave_tb;
    parameter IO_LOGICAL = 8;
    parameter DATA_BITS = 8;
    parameter ADDR_BITS = 12;

    localparam STARTS_ADDR = 0;
    localparam STOPS_ADDR = 1;
    localparam ACKS_ADDR = 2;
    localparam NACKS_ADDR = 4;
    localparam TRANSFERS_ADDR = 6;
    localparam TO_SLAVE_CHECKSUM_ADDR = 8;
    localparam STATE_NUM_ADDR = 12;
    localparam DEV_ADDR_MATCHES_ADDR = 13;
    localparam DEV_ADDR_ADDR = 14;
    localparam TEST_MODE_ADDR = 16;
    localparam PREV_TO_SLAVE_4_ADDR = 17;
    localparam PREV_TO_SLAVE_3_ADDR = 18;
    localparam PREV_TO_SLAVE_2_ADDR = 19;
    localparam PREV_TO_SLAVE_1_ADDR = 20;
    localparam NEXT_FROM_SLAVE_ADDR = 21;
    localparam NUM_WRITES_ADDR = 22;
    localparam NUM_READS_ADDR = 24;
    localparam FROM_SLAVE_CHECKSUM_ADDR = 26;

    integer expected_starts;
    integer expected_stops;
    integer expected_acks;
    integer expected_nacks;
    integer expected_transfers;
    integer expected_to_slave_checksum;
    integer expected_from_slave_checksum;
    integer expected_dev_addr_matches;
    integer expected_prev_to_slave_4;
    integer expected_prev_to_slave_3;
    integer expected_prev_to_slave_2;
    integer expected_prev_to_slave_1;
    integer expected_next_from_slave;
    integer expected_num_writes;
    integer expected_num_reads;

    integer test_periods [2:0];

    initial begin
        test_periods[0] = `SCL100KHz;
        test_periods[1] = `SCL400KHz;
        test_periods[2] = `SCL1MHz;
    end

    reg clk;
    reg rst;
    integer i, j, k;
    reg [7:0] data_in = 0;
    reg [7:0] data = 0;
    reg [IO_LOGICAL - 1:0] logical_in;
    wire [IO_LOGICAL - 1:0] i2c_master_val;
    wire [IO_LOGICAL - 1:0] i2c_master_drive;
    wire [ADDR_BITS - 1:0] PADDR;
    wire i2c_master_psel;
    wire PENABLE;
    wire PWRITE;
    wire [DATA_BITS - 1:0] PWDATA;
    wire [DATA_BITS - 1:0] i2c_master_prdata;
    reg [15:0] dev_addr = 16'h0098;
    integer starting_send_val;

    apb2_slave_tester #(.ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS)) apb2_slave_tester (
        .PCLK(clk),
        .PADDR(PADDR),
        .PSEL(i2c_master_psel),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(i2c_master_prdata)
    );

    i2c_master_tester_apb2_slave #(.IO_LOGICAL(IO_LOGICAL)) i2c_master_tester_apb2_slave (
        clk,
        rst,
        logical_in,
        i2c_master_val,
        i2c_master_drive,
        PADDR,
        i2c_master_psel,
        PENABLE,
        PWRITE,
        PWDATA,
        i2c_master_prdata
    );

    initial  begin
        $dumpfile ("top.vcd");
        $dumpvars;
        clk = 0;
        forever begin
            #5 clk = !clk;
        end
    end

    initial begin
        // test all aspects of i2c at 3 different frequencies
        for (j = 0; j < 3; j = j + 1) begin
            expected_starts = 0;
            expected_stops = 0;
            expected_acks = 0;
            expected_nacks = 0;
            expected_transfers = 0;
            expected_to_slave_checksum = 0;
            expected_from_slave_checksum = 0;
            expected_dev_addr_matches = 0;
            expected_prev_to_slave_4 = 0;
            expected_prev_to_slave_3 = 0;
            expected_prev_to_slave_2 = 0;
            expected_prev_to_slave_1 = 0;
            expected_next_from_slave = 0;
            expected_num_writes = 0;
            expected_num_reads = 0;
            rst = 1;
            logical_in[IO_LOGICAL - 1:0] = 0;
            #(5 * `CLK_CYCLE);
            rst = 0;
            #(5 * `CLK_CYCLE);
            start_condition(test_periods[j]);
            i2c_write(8'h98, test_periods[j]);
            receive_ack_nack(test_periods[j]);
            for (k = 0; k < 10; k = k + 1) begin
                i2c_write(k[7:0], test_periods[j]);
                receive_ack_nack(test_periods[j]);
            end
            stop_condition(test_periods[j]);
            start_condition(test_periods[j]);
            i2c_write(8'h99, test_periods[j]);
            receive_ack_nack(test_periods[j]);
            starting_send_val = 32'h0032;
            apb2_slave_tester.write(NEXT_FROM_SLAVE_ADDR, starting_send_val);
            for (k = 0; k < 9; k = k + 1) begin
                i2c_read(test_periods[j], data_in);
                send_ack(test_periods[j]);
                `util_assert_equal(starting_send_val, data_in);
                starting_send_val = starting_send_val + 1;
            end
            i2c_read(test_periods[j], data_in);
            send_nack(test_periods[j]);
            `util_assert_equal(starting_send_val, data_in);
            starting_send_val = starting_send_val + 1;
            stop_condition(test_periods[j]);
            apb2_slave_tester.write(DEV_ADDR_ADDR, 8'hAA);
            #(20 * `CLK_CYCLE);
            apb2_slave_tester.read(DEV_ADDR_ADDR, data);
            `util_assert_equal(8'hAA, data);
            apb2_slave_tester.write(DEV_ADDR_ADDR, 8'h98);
            #(20 * `CLK_CYCLE);
            apb2_slave_tester.read(DEV_ADDR_ADDR, data);
            `util_assert_equal(8'h98, data);
            apb2_slave_tester.read(STATE_NUM_ADDR, data);
            `util_assert_equal(0, data);
            apb2_slave_tester.read(STARTS_ADDR, data);
            `util_assert_equal(expected_starts, data);
            apb2_slave_tester.read(STOPS_ADDR, data);
            `util_assert_equal(expected_stops, data);
            apb2_slave_tester.read(ACKS_ADDR, data);
            `util_assert_equal(expected_acks[7:0], data);
            apb2_slave_tester.read(ACKS_ADDR+1, data);
            `util_assert_equal(expected_acks[15:8], data);
            apb2_slave_tester.read(NACKS_ADDR, data);
            `util_assert_equal(expected_nacks[7:0], data);
            apb2_slave_tester.read(NACKS_ADDR+1, data);
            `util_assert_equal(expected_nacks[15:8], data);
            apb2_slave_tester.read(TRANSFERS_ADDR, data);
            `util_assert_equal(expected_transfers[7:0], data);
            apb2_slave_tester.read(TRANSFERS_ADDR+1, data);
            `util_assert_equal(expected_transfers[15:8], data);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR, data);
            `util_assert_equal(expected_to_slave_checksum[7:0], data);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR+1, data);
            `util_assert_equal(expected_to_slave_checksum[15:8], data);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR+2, data);
            `util_assert_equal(expected_to_slave_checksum[23:16], data);
            apb2_slave_tester.read(TO_SLAVE_CHECKSUM_ADDR+3, data);
            `util_assert_equal(expected_to_slave_checksum[31:24], data);
            apb2_slave_tester.read(FROM_SLAVE_CHECKSUM_ADDR, data);
            `util_assert_equal(expected_from_slave_checksum[7:0], data);
            apb2_slave_tester.read(FROM_SLAVE_CHECKSUM_ADDR+1, data);
            `util_assert_equal(expected_from_slave_checksum[15:8], data);
            apb2_slave_tester.read(FROM_SLAVE_CHECKSUM_ADDR+2, data);
            `util_assert_equal(expected_from_slave_checksum[23:16], data);
            apb2_slave_tester.read(FROM_SLAVE_CHECKSUM_ADDR+3, data);
            `util_assert_equal(expected_from_slave_checksum[31:24], data);
            apb2_slave_tester.read(DEV_ADDR_MATCHES_ADDR, data);
            `util_assert_equal(expected_dev_addr_matches, data);
            apb2_slave_tester.read(PREV_TO_SLAVE_4_ADDR, data);
            `util_assert_equal(expected_prev_to_slave_4, data);
            apb2_slave_tester.read(PREV_TO_SLAVE_3_ADDR, data);
            `util_assert_equal(expected_prev_to_slave_3, data);
            apb2_slave_tester.read(PREV_TO_SLAVE_2_ADDR, data);
            `util_assert_equal(expected_prev_to_slave_2, data);
            apb2_slave_tester.read(PREV_TO_SLAVE_1_ADDR, data);
            `util_assert_equal(expected_prev_to_slave_1, data);
            apb2_slave_tester.read(NUM_WRITES_ADDR, data);
            `util_assert_equal(expected_num_writes[7:0], data);
            apb2_slave_tester.read(NUM_WRITES_ADDR+1, data);
            `util_assert_equal(expected_num_writes[15:8], data);
            apb2_slave_tester.read(NUM_READS_ADDR, data);
            `util_assert_equal(expected_num_reads[7:0], data);
            apb2_slave_tester.read(NUM_READS_ADDR+1, data);
            `util_assert_equal(expected_num_reads[15:8], data);
            #(20 * `CLK_CYCLE);
            rst = 1;
            #(20 * `CLK_CYCLE);
            rst = 0;
            #(20 * `CLK_CYCLE);
        end
        // test test_mode
        apb2_slave_tester.write(TEST_MODE_ADDR, 0);
        start_condition(`SCL100KHz);
        i2c_read(`SCL100KHz, data_in);
        send_nack(`SCL100KHz);
        stop_condition(`SCL100KHz);
        `util_assert_equal(0, data_in);

        $finish;
    end

    task start_condition;
        input [31:0] scl_period;
        begin
            expected_starts = expected_starts + 1;
            #(`CLK_CYCLE * scl_period);
            logical_in[0] = 1;
            logical_in[1] = 1;
            #(`CLK_CYCLE * scl_period);
            logical_in[0] = 0;
            #(`CLK_CYCLE * scl_period);
            logical_in[1] = 0;
            #(`CLK_CYCLE * scl_period);
        end
    endtask

    task stop_condition;
        input [31:0] scl_period;
        begin
            expected_stops = expected_stops + 1;
            #(`CLK_CYCLE * scl_period);
            logical_in[0] = 0;
            logical_in[1] = 1;
            #(`CLK_CYCLE * scl_period);
            logical_in[0] = 1;
            #(`CLK_CYCLE * scl_period);
        end
    endtask

    task i2c_write;
        input [7:0] write_data;
        input [31:0] scl_period;
        begin
            if ((write_data & 16'hfffe) == dev_addr) begin
                expected_dev_addr_matches = expected_dev_addr_matches + 1;
            end
            else begin
                expected_to_slave_checksum = expected_to_slave_checksum + write_data;
                expected_prev_to_slave_4 = expected_prev_to_slave_3;
                expected_prev_to_slave_3 = expected_prev_to_slave_2;
                expected_prev_to_slave_2 = expected_prev_to_slave_1;
                expected_prev_to_slave_1 = write_data;
                expected_num_writes = expected_num_writes + 1;
            end
            expected_transfers = expected_transfers + 1;
            for (i = 8; i > 0; i = i - 1) begin
                logical_in[0] = write_data[i-1];
                #((`CLK_CYCLE * scl_period) / 2);
                logical_in[1] = 1;
                #((`CLK_CYCLE * scl_period) / 2);
                logical_in[1] = 0;
            end
        end
    endtask

    task i2c_read;
        input [31:0] scl_period;
        output reg [7:0] data_in_l;
        begin
            expected_transfers = expected_transfers + 1;
            expected_num_reads = expected_num_reads + 1;
            logical_in[0] = 1'bz;
            for (i = 8; i > 0; i = i - 1) begin
                #((`CLK_CYCLE * scl_period) / 2);
                logical_in[1] = 1;
                data_in_l[i-1] = ~i2c_master_drive[0];
                #((`CLK_CYCLE * scl_period) / 2);
                logical_in[1] = 0;
            end
            expected_from_slave_checksum = expected_from_slave_checksum + data_in_l;
        end
    endtask

    task receive_ack_nack;
        input [31:0] scl_period;
        begin
            logical_in[0] = 1'bz;
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 1;
            if (i2c_master_val[0] == 0) begin
                expected_acks = expected_acks + 1;
            end
            else if (i2c_master_val[0] == 1) begin
                expected_nacks = expected_nacks + 1;
            end
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 0;
        end
    endtask

    task send_ack;
        input [31:0] scl_period;
        begin
            logical_in[0] = 0;
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 1;
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 0;
            expected_acks = expected_acks + 1;
        end
    endtask

    task send_nack;
        input [31:0] scl_period;
        begin
            logical_in[0] = 1;
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 1;
            #((`CLK_CYCLE * scl_period) / 2);
            logical_in[1] = 0;
            expected_nacks = expected_nacks + 1;
        end
    endtask

endmodule
