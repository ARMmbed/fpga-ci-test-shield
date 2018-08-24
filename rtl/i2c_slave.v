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

// I2C slave module
//
// This modules acts as an I2C slave.
//
// sda_in - I2C data from master
// sda_out - I2C data to master
// sda_drive - set when sda_in is high impedance and data needs to be sent to master
// scl - I2C clk line
//
`define IDLE               0
`define GET_DEV_ADDR       1
`define GET_DATA           2
`define SEND_DATA          3
`define ACK                4
`define NACK               5
`define DETECT_ACK_OR_NACK 6
`define STATE_BITS         3

module i2c_slave(
    input wire clk,
    input wire rst,
    input wire sda_in,
    output reg sda_out,
    output reg sda_drive,
    input wire scl,
    output reg ack,
    output reg nack,
    input wire [15:0] dev_addr,
    output reg transfer_complete,
    output reg dev_addr_match,
    output reg dev_addr_mismatch,
    output reg [`STATE_BITS - 1:0] state,
    output reg read,
    output reg write,
    output reg [7:0] din,
    output reg [7:0] dout,
    output reg start_cond,
    output reg stop_cond,
    input wire [7:0] send_data
    );

    reg [`STATE_BITS - 1:0] state_w;
    reg read_w;
    reg write_w;
    reg [7:0] din_w;
    reg [7:0] dout_w;
    reg [`STATE_BITS - 1:0] next_state;
    reg [`STATE_BITS - 1:0] next_state_w;
    reg [3:0] data_counter;
    reg [3:0] data_counter_w;
    reg [7:0] dev_addr_in;
    reg [7:0] dev_addr_in_w;
    reg [7:0] data_in;
    reg [7:0] data_in_w;
    reg [2:0] ack_edges;
    reg [2:0] ack_edges_w;
    reg sda_rising_edge;
    reg sda_falling_edge;
    reg scl_rising_edge;
    reg scl_falling_edge;
    reg [3:0] sda_stream;
    reg [3:0] scl_stream;

    // Combinational Logic
    // state machine
    always @(*) begin
        sda_out = 0;
        sda_drive = 0;
        ack = 0;
        nack = 0;
        transfer_complete = 0;
        dev_addr_match = 0;
        dev_addr_mismatch = 0;
        state_w = state;
        read_w = read;
        write_w = write;
        din_w = din;
        dout_w = dout;
        next_state_w = next_state;
        data_counter_w = data_counter;
        dev_addr_in_w = dev_addr_in;
        data_in_w = data_in;
        ack_edges_w = ack_edges;
        if (rst == 0) begin
            if (state == `IDLE) begin
                transfer_complete = 0;
                ack = 0;
                nack = 0;
                if (start_cond == 1) begin
                    //start condition
                    data_counter_w = 0;
                    state_w = `GET_DEV_ADDR;
                end
                else begin
                    state_w = `IDLE;
                end
            end
            else if (state == `GET_DEV_ADDR) begin
                read_w = 0;
                write_w = 0;
                if (data_counter == 8) begin
                    if ((dev_addr_in & 16'hfffe) != dev_addr) begin
                        state_w = `NACK;
                        dev_addr_mismatch = 1;
                    end
                    else if (dev_addr_in[0] == 1) begin
                        state_w = `ACK;
                        next_state_w = `SEND_DATA;
                        dev_addr_match = 1;
                        din_w = dev_addr_in;
                    end
                    else begin
                        state_w = `ACK;
                        next_state_w = `GET_DATA;
                        dev_addr_match = 1;
                        din_w = dev_addr_in;
                    end
                    data_counter_w = 0;
                end
                else if (scl_rising_edge == 1) begin
                    dev_addr_in_w[7-data_counter] = sda_in;
                    data_counter_w = data_counter + 1;
                end
            end
            else if (state == `GET_DATA) begin
                ack = 0;
                nack = 0;
                transfer_complete = 0;
                read_w = 0;
                write_w = 1;
                if (start_cond == 1) begin
                    data_counter_w = 0;
                    state_w = `GET_DEV_ADDR;
                end
                else if (stop_cond == 1) begin
                    data_counter_w = 0;
                    state_w = `IDLE;
                end
                else if (data_counter == 8) begin
                    state_w = `ACK;
                    next_state_w = `GET_DATA;
                    data_counter_w = 0;
                    din_w = data_in;
                end
                else if (scl_rising_edge == 1) begin
                    data_in_w[7-data_counter] = sda_in;
                    data_counter_w = data_counter + 1;
                end
            end
            else if (state == `SEND_DATA) begin
                ack = 0;
                nack = 0;
                transfer_complete = 0;
                write_w = 0;
                read_w = 1;
                sda_drive = ~send_data[7-data_counter];
                if (scl_falling_edge == 1) begin
                    if (data_counter == 7) begin
                        state_w = `DETECT_ACK_OR_NACK;
                        data_counter_w = 0;
                        dout_w = send_data;
                    end
                    else begin
                        data_counter_w = data_counter + 1;
                    end
                end
            end
            else if (state == `ACK) begin
                dev_addr_match = 0;
                if (ack_edges >= 1) begin
                    sda_drive = 1;
                end
                if ((scl_rising_edge == 1) || (scl_falling_edge == 1)) begin
                    ack_edges_w = ack_edges + 1;
                    if (ack_edges == 2) begin
                        ack_edges_w = 0;
                        state_w = next_state;
                        ack = 1;
                        transfer_complete = 1;
                    end
                    else begin
                        ack = 0;
                        transfer_complete = 0;
                    end
                end
            end
            else if (state == `NACK) begin
                if ((scl_rising_edge == 1) || (scl_falling_edge == 1)) begin
                    ack_edges_w = ack_edges + 1;
                    if (ack_edges == 2) begin
                        ack_edges_w = 0;
                        state_w = `IDLE;
                        nack = 1;
                        transfer_complete = 1;
                    end
                    else begin
                        nack = 0;
                        transfer_complete = 0;
                    end
                end
            end
            else if (state == `DETECT_ACK_OR_NACK) begin
                if (scl_rising_edge == 1) begin
                    if (sda_in == 1) begin//NACK
                        next_state_w = `IDLE;
                        transfer_complete = 1;
                        nack = 1;
                    end
                    else if (sda_in == 0) begin//ACK
                        next_state_w = `SEND_DATA;
                        transfer_complete = 1;
                        data_counter_w = 0;
                        ack = 1;
                    end
                end
                else if (scl_falling_edge == 1) begin
                    state_w = next_state;
                end
            end

        end
        // rst == 1
        else begin
            state_w = `IDLE;
            next_state_w = `IDLE;
            ack_edges_w = 0;
            data_counter_w = 0;
            dev_addr_in_w = 0;
            data_in_w = 0;
            sda_out = 0;
            sda_drive = 0;
            ack = 0;
            nack = 0;
            transfer_complete = 0;
            dev_addr_match = 0;
            dev_addr_mismatch = 0;
            read_w = 0;
            write_w = 0;
            din_w = 0 ;
            dout_w = 0;
        end
    end

    // start and stop conditions
    always @(*) begin
        if (rst == 0) begin
            //start condition
            if ((sda_falling_edge == 1) && (scl_stream == 4'b1111)) begin
                start_cond = 1;
            end
            else begin
                start_cond = 0;
            end
            //stop condition
            if ((sda_rising_edge == 1) && (scl_stream == 4'b1111)) begin
                stop_cond = 1;
            end
            else begin
                stop_cond = 0;
            end
        end
        // rst == 1
        else begin
            start_cond = 0;
            stop_cond = 0;
        end
    end

    // sda and scl edge detection
    always @(*) begin
        if (rst == 0) begin
            //sda edge detection
            if (sda_stream == 4'b0011) begin
                sda_rising_edge = 1;
            end
            else begin
                sda_rising_edge = 0;
            end
            if (sda_stream == 4'b1100) begin
                sda_falling_edge = 1;
            end
            else begin
                sda_falling_edge = 0;
            end
            //scl edge detection
            if (scl_stream == 4'b0011) begin
                scl_rising_edge = 1;
            end
            else begin
                scl_rising_edge = 0;
            end
            if (scl_stream == 4'b1100) begin
                scl_falling_edge = 1;
            end
            else begin
                scl_falling_edge = 0;
            end
        end
        // rst == 1
        else begin
            sda_rising_edge = 0;
            sda_falling_edge = 0;
            scl_rising_edge = 0;
            scl_falling_edge = 0;
        end
    end

    // Sequential Logic
    always @(posedge clk) begin
        state <= state_w;
        next_state <= next_state_w;
        sda_stream <= {sda_stream[2:0],sda_in};
        scl_stream <= {scl_stream[2:0],scl};
        ack_edges <= ack_edges_w;
        data_counter <= data_counter_w;
        dev_addr_in <= dev_addr_in_w;
        data_in <= data_in_w;
        read <= read_w;
        write <= write_w;
        din <= din_w;
        dout <= dout_w;
    end

endmodule
