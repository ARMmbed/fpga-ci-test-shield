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

// I2C master tester module
//
// This modules contains an I2C slave and is used for testing
// an I2C master.
//
// APB interface:
// RO - Read Only
// RW - Read Write
// Addr     Size    Name                                    Type
// +0       1       starts                                  RO
// +1       1       stops                                   RO
// +2       2       acks                                    RO
// +4       2       nacks                                   RO
// +6       2       transfers                               RO
// +8       4       checksum_to_slave                       RO
// +12      1       state_num                               RO
// +13      1       dev_addr_matches                        RO
// +14      2       dev_addr                                RW
// +16      1       test_mode                               WO
// +17      1       prev_to_slave_4                         RO
// +18      1       prev_to_slave_3                         RO
// +19      1       prev_to_slave_2                         RO
// +20      1       prev_to_slave_1                         RO
// +21      1       next_from_slave                         RW
// +22      2       num_writes                              RO
// +24      2       num_reads                               RO
// +26      4       checksum_from_slave                     RO
// +30      1       dev_addr_mismatches                     RO
//

// SDA = logical 0
// SCL = logical 1
module i2c_master_tester_apb2_slave #(
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
        output reg [DATA_BITS - 1:0] PRDATA
    );

    localparam ADDR_BITS = 12;
    localparam DATA_BITS = 8;

    // 0 - The number of start conditions
    reg [7:0] starts;
    reg [7:0] starts_w;
    // 1 - The number of stop conditions
    reg [7:0] stops;
    reg [7:0] stops_w;
    // 2 - The number of acks sent to master by slave
    reg [15:0] acks;
    reg [15:0] acks_w;
    // 4 - The number of nacks sent to master by slave
    reg [15:0] nacks;
    reg [15:0] nacks_w;
    // 6 - The number of transfers
    reg [15:0] transfers;
    reg [15:0] transfers_w;
    // 8 - The checksum
    reg [31:0] checksum_to_slave;
    reg [31:0] checksum_to_slave_w;
    // 12 - The state number
    reg [2:0] state_num;
    wire [2:0] state_num_w;
    // 13 - The number of device address matches
    reg [7:0] dev_addr_matches;
    reg [7:0] dev_addr_matches_w;
    // 14 - The device address
    reg [15:0] dev_addr;
    wire [15:0] dev_addr_w;
    assign dev_addr_w = dev_addr;
    // 16 - Reg for setting SDA
    reg test_mode = 1;//0: force SDA low, 1: SDA = value from slave
    // 17 - Value written to slave in the fourth to last transaction
    reg [7:0] prev_to_slave_4;
    reg [7:0] prev_to_slave_4_w;
    // 18 - Value written to slave in the third to last transaction
    reg [7:0] prev_to_slave_3;
    reg [7:0] prev_to_slave_3_w;
    // 19 - Value written to slave in the second to last transaction
    reg [7:0] prev_to_slave_2;
    reg [7:0] prev_to_slave_2_w;
    // 20 - Value written to slave in the last transaction
    reg [7:0] prev_to_slave_1;
    reg [7:0] prev_to_slave_1_w;
    // 21 - Value to be read from slave in next read transaction
    reg [7:0] next_from_slave;
    wire [7:0] next_from_slave_w;
    assign next_from_slave_w = next_from_slave;
    // 22 - The number of writes to the slave
    reg [15:0] num_writes;
    reg [15:0] num_writes_w;
    // 24 - The number of reads from the slave
    reg [15:0] num_reads;
    reg [15:0] num_reads_w;
    // 26 - The checksum
    reg [31:0] checksum_from_slave;
    reg [31:0] checksum_from_slave_w;
    // 30 - The number of device address matches
    reg [7:0] dev_addr_mismatches;
    reg [7:0] dev_addr_mismatches_w;

    // Set unused outputs low
    assign logical_val[IO_LOGICAL - 1:1] = 0;
    assign logical_drive[IO_LOGICAL - 1:1] = 0;

    wire logical_drive_sda;
    wire logical_val_sda;
    assign logical_drive[0] = logical_drive_sda | ~test_mode;
    assign logical_val[0] = test_mode ? logical_val_sda : 0;

    wire [3:0] sda_stream, scl_stream;
    reg ack;
    wire ack_w;
    reg nack;
    wire nack_w;
    reg transfer_complete;
    wire transfer_complete_w;
    reg dev_addr_match;
    wire dev_addr_match_w;
    reg dev_addr_mismatch;
    wire dev_addr_mismatch_w;
    wire read_w;
    wire write_w;
    wire [7:0] din_w;
    wire [7:0] dout_w;
    reg start;
    wire start_w;
    reg stop;
    wire stop_w;
    reg incrmt_send_data;

    i2c_slave i2c_slave(
        .clk(clk),
        .rst(rst),
        .sda_in(logical_in[0]),
        .sda_out(logical_val_sda),
        .sda_drive(logical_drive_sda),
        .scl(logical_in[1]),
        .ack(ack_w),
        .nack(nack_w),
        .dev_addr(dev_addr_w),
        .transfer_complete(transfer_complete_w),
        .dev_addr_match(dev_addr_match_w),
        .dev_addr_mismatch(dev_addr_mismatch_w),
        .state(state_num_w),
        .read(read_w),
        .write(write_w),
        .din(din_w),
        .dout(dout_w),
        .start_cond(start_w),
        .stop_cond(stop_w),
        .send_data(next_from_slave_w)
    );

    always @(*) begin
        starts_w = starts;
        stops_w = stops;
        acks_w = acks;
        nacks_w = nacks;
        transfers_w = transfers;
        dev_addr_matches_w = dev_addr_matches;
        dev_addr_mismatches_w = dev_addr_mismatches;
        prev_to_slave_4_w = prev_to_slave_4;
        prev_to_slave_3_w = prev_to_slave_3;
        prev_to_slave_2_w = prev_to_slave_2;
        prev_to_slave_1_w = prev_to_slave_1;
        num_writes_w = num_writes;
        num_reads_w = num_reads;
        checksum_to_slave_w = checksum_to_slave;
        checksum_from_slave_w = checksum_from_slave;
        incrmt_send_data = 0;
        if (rst == 0) begin
            //starts
            if (start == 1) begin
                starts_w = starts + 1;
            end
            //stops
            if (stop == 1) begin
                stops_w = stops + 1;
            end
            //acks
            if (ack == 1) begin
                acks_w = acks + 1;
            end
            //nacks
            if (nack == 1) begin
                nacks_w = nacks + 1;
            end
            //transfers
            if (transfer_complete == 1) begin
                transfers_w = transfers + 1;
                if (read_w == 1) begin
                    num_reads_w = num_reads + 1;
                    checksum_from_slave_w = checksum_from_slave + dout_w;
                    incrmt_send_data = 1;
                end
                if (write_w == 1) begin
                    num_writes_w = num_writes + 1;
                    checksum_to_slave_w = checksum_to_slave + din_w;
                    prev_to_slave_1_w = din_w;
                    prev_to_slave_2_w = prev_to_slave_1;
                    prev_to_slave_3_w = prev_to_slave_2;
                    prev_to_slave_4_w = prev_to_slave_3;
                end
            end
            //dev_addr_matches
            if (dev_addr_match == 1) begin
                dev_addr_matches_w = dev_addr_matches + 1;
            end
            if (dev_addr_mismatch == 1) begin
                dev_addr_mismatches_w = dev_addr_mismatches + 1;
            end
        end
        // rst == 1
        else begin
            starts_w = 0;
            stops_w = 0;
            acks_w = 0;
            nacks_w = 0;
            transfers_w = 0;
            dev_addr_matches_w = 0;
            dev_addr_mismatches_w = 0;
            prev_to_slave_4_w = 0;
            prev_to_slave_3_w = 0;
            prev_to_slave_2_w = 0;
            prev_to_slave_1_w = 0;
            num_writes_w = 0;
            num_reads_w = 0;
            checksum_to_slave_w = 0;
            checksum_from_slave_w = 0;
            incrmt_send_data = 0;
        end
    end

    always @(posedge clk) begin
        starts <= starts_w;
        stops <= stops_w;
        acks <= acks_w;
        nacks <= nacks_w;
        transfers <= transfers_w;
        checksum_to_slave <= checksum_to_slave_w;
        checksum_from_slave <= checksum_from_slave_w;
        state_num <= state_num_w;
        dev_addr_matches <= dev_addr_matches_w;
        dev_addr_mismatches <= dev_addr_mismatches_w;
        ack <= ack_w;
        nack <= nack_w;
        transfer_complete <= transfer_complete_w;
        dev_addr_match <= dev_addr_match_w;
        dev_addr_mismatch <= dev_addr_mismatch_w;
        prev_to_slave_4 <= prev_to_slave_4_w;
        prev_to_slave_3 <= prev_to_slave_3_w;
        prev_to_slave_2 <= prev_to_slave_2_w;
        prev_to_slave_1 <= prev_to_slave_1_w;
        num_writes <= num_writes_w;
        num_reads <= num_reads_w;
        start <= start_w;
        stop <= stop_w;
        if (rst == 1) begin
            dev_addr <= 16'h0098;
            test_mode <= 1;
            next_from_slave <= 1;
        end
        if (incrmt_send_data == 1) begin
            next_from_slave <= (next_from_slave + 1) & 8'hff;
        end

        // APB interface
        if (PSEL) begin
            if (PWRITE && PENABLE) begin
                case (PADDR)
                    // Writeable values
                    14: dev_addr[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                    15: dev_addr[DATA_BITS * 1+:DATA_BITS] <= PWDATA;

                    16: test_mode <= PWDATA;

                    21: next_from_slave <= PWDATA;

                    default:;
                endcase
            end
            if (!PWRITE) begin
                case (PADDR)
                    // Readable values
                    0:  PRDATA <= starts;

                    1:  PRDATA <= stops;

                    2:  PRDATA <= acks[DATA_BITS * 0+:DATA_BITS];
                    3:  PRDATA <= acks[DATA_BITS * 1+:DATA_BITS];

                    4:  PRDATA <= nacks[DATA_BITS * 0+:DATA_BITS];
                    5:  PRDATA <= nacks[DATA_BITS * 1+:DATA_BITS];

                    6:  PRDATA <= transfers[DATA_BITS * 0+:DATA_BITS];
                    7:  PRDATA <= transfers[DATA_BITS * 1+:DATA_BITS];

                    8:  PRDATA <= checksum_to_slave[DATA_BITS * 0+:DATA_BITS];
                    9:  PRDATA <= checksum_to_slave[DATA_BITS * 1+:DATA_BITS];
                    10: PRDATA <= checksum_to_slave[DATA_BITS * 2+:DATA_BITS];
                    11: PRDATA <= checksum_to_slave[DATA_BITS * 3+:DATA_BITS];

                    12: PRDATA <= {5'h0, state_num};

                    13: PRDATA <= dev_addr_matches;

                    14: PRDATA <= dev_addr[DATA_BITS * 0+:DATA_BITS];
                    15: PRDATA <= dev_addr[DATA_BITS * 1+:DATA_BITS];

                    17: PRDATA <= prev_to_slave_4;

                    18: PRDATA <= prev_to_slave_3;

                    19: PRDATA <= prev_to_slave_2;

                    20: PRDATA <= prev_to_slave_1;

                    21: PRDATA <= next_from_slave;

                    22: PRDATA <= num_writes[DATA_BITS * 0+:DATA_BITS];
                    23: PRDATA <= num_writes[DATA_BITS * 1+:DATA_BITS];

                    24: PRDATA <= num_reads[DATA_BITS * 0+:DATA_BITS];
                    25: PRDATA <= num_reads[DATA_BITS * 1+:DATA_BITS];

                    26: PRDATA <= checksum_from_slave[DATA_BITS * 0+:DATA_BITS];
                    27: PRDATA <= checksum_from_slave[DATA_BITS * 1+:DATA_BITS];
                    28: PRDATA <= checksum_from_slave[DATA_BITS * 2+:DATA_BITS];
                    29: PRDATA <= checksum_from_slave[DATA_BITS * 3+:DATA_BITS];

                    30: PRDATA <= dev_addr_mismatches;

                    default: PRDATA <= 0;
                endcase
            end
        end
    end

endmodule
