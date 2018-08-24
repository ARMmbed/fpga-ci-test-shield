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

// UART tester module
//
// This modules contains a UART and is used for testing
// a UART.
//
// APB interface:
// Addr     Size    Name                                    Type
// +0x000   4       control - reserved                      RW
// +0x004   2       baud_divisor                            RW
//                      baudrate = FPGA clock / baud_divisor
// +0x006   10      reserved
// +0x010   1       bit_count - valid values are 1 to 16    RW
// +0x011   1       stop_count - valid values are 1 to 16   RW
// +0x012   1       parity setting                          RW
//                      bit 0 = parity enable
//                      bit 1 = parity
//                              0 - even parity
//                              1 - odd parity
// +0x013   237     reserved
// +0x100   4       rx_control
//                      bit 0 - rx enable                   RW
//                      bit 1 - rx reset                    WO
//                      bit 2 to 32 reserved
// +0x104   4       rx_checksum                             RO
// +0x108   4       rx_count                                RO
// +0x10C   4       rx_parity_errors                        RO
// +0x110   4       rx_stop_errors                          RO
// +0x114   4       rx_framing_errors                       RO
// +0x118   2       rx_prev_4                               RO
// +0x11A   2       rx_prev_3                               RO
// +0x11C   2       rx_prev_2                               RO
// +0x11E   2       rx_prev_1                               RO
// +0x120   4       rx_rts_to_last_start      *FUTURE*      RO
// +0x124   4       rts_assert_time_min       *FUTURE*      RW
// +0x128   4       rts_assert_time_cur       *FUTURE*      RW
// +0x12C   4       rts_assert_time_max       *FUTURE*      RW
// +0x130   4       rts_assert_time_delta     *FUTURE*      RW
// +0x134   4       rts_deassert_time_min     *FUTURE*      RW
// +0x138   4       rts_deassert_time_cur     *FUTURE*      RW
// +0x13C   4       rts_deassert_time_max     *FUTURE*      RW
// +0x140   4       rts_deassert_time_delta   *FUTURE*      RW
// +0x148   184     reserved
// +0x200   4       tx_control
//                      bit 0 - tx enable                   RW
//                      bit 1 - tx reset                    WO
//                      bit 2 - cts enable                  RW
//                      bit 3 to 32 reserved
// +0x204   4       tx_count - Number of bytes to send      RW
// +0x208   2       tx_next - Next value to send. Values    RW
//                            are sent sequentially
//                            incrementing from tx_next.
// +0x20C   2       reserved
// +0x210   4       cts_deactivate_delay                    RW
// +0x214   4       tx_delay                                RW
//
module uart_tester_apb2_slave #(
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

    wire tx;
    wire rx;
    wire cts;
    wire cts_delayed;
    wire [15:0] rx_data;
    wire rx_done;
    wire rx_parity_error;
    wire rx_stop_error;
    wire rx_framing_error;

    wire tx_strobe_started;
    wire tx_send;

    reg [15:0] baud_divisor;
    reg [3:0] bit_count;
    reg [3:0] stop_count;
    reg parity_enable;
    reg parity_odd_n_even;

    reg rx_enable;
    reg rx_reset;
    reg [31:0] rx_checksum;
    reg [31:0] rx_count;
    reg [31:0] rx_parity_errors;
    reg [31:0] rx_stop_errors;
    reg [31:0] rx_framing_errors;
    reg [15:0] rx_prev[0:4];

    reg tx_enable;
    reg tx_reset;
    reg cts_enable;
    reg [31:0] tx_count;
    reg [15:0] tx_next;
    reg [31:0] cts_deactivate_delay;
    reg [31:0] cts_deactivate_delay_cur;
    reg [31:0] tx_delay;
    reg [31:0] tx_delay_cur;

    // Assign TX to drive pin 0
    assign logical_val[0] = tx;
    assign logical_drive[0] = 1;

    // Assign RX to read pin 1
    assign rx = logical_in[1];
    assign logical_val[1] = 0;
    assign logical_drive[1] = 0;

    // Assign CTS to read pin 2
    assign cts = logical_in[2];
    assign logical_val[2] = 0;
    assign logical_drive[2] = 0;

    // Assign RTS to drive pin 3
    assign logical_val[3] = 0;
    assign logical_drive[3] = 1;

    // Set unused outputs low
    assign logical_val[IO_LOGICAL - 1:4] = 0;
    assign logical_drive[IO_LOGICAL - 1:4] = 0;

    assign cts_delayed = cts_deactivate_delay_cur == 0 ? cts : 0;
    assign tx_send = (tx_count > 0) && tx_enable && (tx_delay_cur == 0) && (!cts_enable || !cts_delayed);

    uart_rx uart_rx(
        .clk(clk),
        .rst(rst),
        .enable(rx_enable),
        .div(baud_divisor),
        .parity_enable(parity_enable),
        .parity_odd_n_even(parity_odd_n_even),
        .bit_count(bit_count),
        .stop_count(stop_count),
        .rx(rx),
        .strobe_done(rx_done),
        .data(rx_data),
        .parity_error(rx_parity_error),
        .stop_error(rx_stop_error),
        .other_error(rx_framing_error)
    );

    uart_tx uart_tx(
        .clk(clk),
        .rst(rst),
        .div(baud_divisor),
        .parity_enable(parity_enable),
        .parity_odd_n_even(parity_odd_n_even),
        .bit_count(bit_count),
        .stop_count(stop_count),
        .data(tx_next),
        .send(tx_send),

        .tx(tx),
        .ready(),
        .strobe_started(tx_strobe_started)
    );

    always @(posedge clk) begin
        if (rst) begin
            baud_divisor <= 16'hFFFF;
            bit_count <= 8;
            stop_count <= 1;
            parity_enable <= 0;
            parity_odd_n_even <= 0;

            rx_enable <= 0;
            rx_reset <= 0;
            rx_checksum <= 0;
            rx_count <= 0;
            rx_parity_errors <= 0;
            rx_stop_errors <= 0;
            rx_framing_errors <= 0;
            rx_prev[0] <= 0;
            rx_prev[1] <= 0;
            rx_prev[2] <= 0;
            rx_prev[3] <= 0;

            tx_enable <= 0;
            tx_reset <= 0;
            cts_enable <= 0;
            tx_count <= 0;
            tx_next <= 0;
            cts_deactivate_delay <= 0;
            cts_deactivate_delay_cur <= 0;
            tx_delay <= 0;
            tx_delay_cur <= 0;
        end else begin

            // RX handling
            if (rx_done) begin
                rx_checksum <= rx_checksum + rx_data;
                rx_count <= rx_count + 1;
                rx_prev[0] <= rx_prev[1];
                rx_prev[1] <= rx_prev[2];
                rx_prev[2] <= rx_prev[3];
                rx_prev[3] <= rx_data;

                if (rx_parity_error) begin
                    rx_parity_errors <= rx_parity_errors + 1;
                end
                if (rx_stop_error) begin
                    rx_stop_errors <= rx_stop_errors + 1;
                end
                if (rx_framing_error) begin
                    rx_framing_errors <= rx_framing_errors + 1;
                end
            end

            // TX handling
            if (tx_strobe_started) begin
                if (tx_count > 0) begin
                    tx_count <= tx_count - 1;
                end
                tx_next <= tx_next + 1;
            end

            // TX delay handling
            if (tx_enable) begin
                if (tx_delay_cur > 0) begin
                    tx_delay_cur <= tx_delay_cur - 1;
                end
            end else begin
                tx_delay_cur <= tx_delay;
            end

            // CTS handling
            if (cts_enable) begin
                if (cts) begin
                    if (cts_deactivate_delay_cur > 0) begin
                        cts_deactivate_delay_cur <= cts_deactivate_delay_cur - 1;
                    end
                end else begin
                    cts_deactivate_delay_cur <= cts_deactivate_delay;
                end
            end else begin
                cts_deactivate_delay_cur <= 0;
            end

            // Reset handling
            if (rx_reset) begin
                rx_enable <= 0;
                rx_reset <= 0;
                rx_checksum <= 0;
                rx_count <= 0;
                rx_parity_errors <= 0;
                rx_stop_errors <= 0;
                rx_framing_errors <= 0;
                rx_prev[0] <= 0;
                rx_prev[1] <= 0;
                rx_prev[2] <= 0;
                rx_prev[3] <= 0;
            end

            if (tx_reset) begin
                tx_enable <= 0;
                tx_reset <= 0;
                cts_enable <= 0;
                tx_count <= 0;
                tx_next <= 0;
                cts_deactivate_delay <= 0;
                cts_deactivate_delay_cur <= 0;
                tx_delay <= 0;
                tx_delay_cur <= 0;
            end

            // APB interface
            if (PSEL) begin
                if (PWRITE && PENABLE) begin
                    case (PADDR)
                        // Writeable values
                        'h004: baud_divisor[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                        'h005: baud_divisor[DATA_BITS * 1+:DATA_BITS] <= PWDATA;

                        'h010: bit_count <= PWDATA[3:0] > 0 ? PWDATA[3:0] : 1;
                        'h011: stop_count <= PWDATA[3:0] > 0 ? PWDATA[3:0] : 1;
                        'h012: {parity_odd_n_even, parity_enable} <= PWDATA[1:0];

                        'h100: {rx_reset, rx_enable} <= PWDATA[1:0];

                        'h200: {cts_enable, tx_reset, tx_enable} <= PWDATA[2:0];

                        'h204: tx_count[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                        'h205: tx_count[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                        'h206: tx_count[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                        'h207: tx_count[DATA_BITS * 3+:DATA_BITS] <= PWDATA;

                        'h208: tx_next[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                        'h209: tx_next[DATA_BITS * 1+:DATA_BITS] <= PWDATA;

                        'h210: cts_deactivate_delay[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                        'h211: cts_deactivate_delay[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                        'h212: cts_deactivate_delay[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                        'h213: cts_deactivate_delay[DATA_BITS * 3+:DATA_BITS] <= PWDATA;

                        'h214: tx_delay[DATA_BITS * 0+:DATA_BITS] <= PWDATA;
                        'h215: tx_delay[DATA_BITS * 1+:DATA_BITS] <= PWDATA;
                        'h216: tx_delay[DATA_BITS * 2+:DATA_BITS] <= PWDATA;
                        'h217: tx_delay[DATA_BITS * 3+:DATA_BITS] <= PWDATA;

                        default:;
                    endcase
                end
                if (!PWRITE) begin
                    case (PADDR)
                        // Readable values
                        'h004: PRDATA <= baud_divisor[DATA_BITS * 0+:DATA_BITS];
                        'h005: PRDATA <= baud_divisor[DATA_BITS * 1+:DATA_BITS];

                        'h010: PRDATA <= bit_count;
                        'h011: PRDATA <= stop_count;
                        'h012: PRDATA <= {6'h0, parity_odd_n_even, parity_enable};

                        'h100: PRDATA <= {7'h0, rx_enable};

                        'h104: PRDATA <= rx_checksum[DATA_BITS * 0+:DATA_BITS];
                        'h105: PRDATA <= rx_checksum[DATA_BITS * 1+:DATA_BITS];
                        'h106: PRDATA <= rx_checksum[DATA_BITS * 2+:DATA_BITS];
                        'h107: PRDATA <= rx_checksum[DATA_BITS * 3+:DATA_BITS];

                        'h108: PRDATA <= rx_count[DATA_BITS * 0+:DATA_BITS];
                        'h109: PRDATA <= rx_count[DATA_BITS * 1+:DATA_BITS];
                        'h10A: PRDATA <= rx_count[DATA_BITS * 2+:DATA_BITS];
                        'h10B: PRDATA <= rx_count[DATA_BITS * 3+:DATA_BITS];

                        'h10C: PRDATA <= rx_parity_errors[DATA_BITS * 0+:DATA_BITS];
                        'h10D: PRDATA <= rx_parity_errors[DATA_BITS * 1+:DATA_BITS];
                        'h10E: PRDATA <= rx_parity_errors[DATA_BITS * 2+:DATA_BITS];
                        'h10F: PRDATA <= rx_parity_errors[DATA_BITS * 3+:DATA_BITS];

                        'h110: PRDATA <= rx_stop_errors[DATA_BITS * 0+:DATA_BITS];
                        'h111: PRDATA <= rx_stop_errors[DATA_BITS * 1+:DATA_BITS];
                        'h112: PRDATA <= rx_stop_errors[DATA_BITS * 2+:DATA_BITS];
                        'h113: PRDATA <= rx_stop_errors[DATA_BITS * 3+:DATA_BITS];

                        'h114: PRDATA <= rx_framing_errors[DATA_BITS * 0+:DATA_BITS];
                        'h115: PRDATA <= rx_framing_errors[DATA_BITS * 1+:DATA_BITS];
                        'h116: PRDATA <= rx_framing_errors[DATA_BITS * 2+:DATA_BITS];
                        'h117: PRDATA <= rx_framing_errors[DATA_BITS * 3+:DATA_BITS];

                        'h118: PRDATA <= rx_prev[0][DATA_BITS * 0+:DATA_BITS];
                        'h119: PRDATA <= rx_prev[0][DATA_BITS * 1+:DATA_BITS];
                        'h11A: PRDATA <= rx_prev[1][DATA_BITS * 0+:DATA_BITS];
                        'h11B: PRDATA <= rx_prev[1][DATA_BITS * 1+:DATA_BITS];
                        'h11C: PRDATA <= rx_prev[2][DATA_BITS * 0+:DATA_BITS];
                        'h11D: PRDATA <= rx_prev[2][DATA_BITS * 1+:DATA_BITS];
                        'h11E: PRDATA <= rx_prev[3][DATA_BITS * 0+:DATA_BITS];
                        'h11F: PRDATA <= rx_prev[3][DATA_BITS * 1+:DATA_BITS];

                        'h200: PRDATA <= {7'h0, tx_enable};

                        'h204: PRDATA <= tx_count[DATA_BITS * 0+:DATA_BITS];
                        'h205: PRDATA <= tx_count[DATA_BITS * 1+:DATA_BITS];
                        'h206: PRDATA <= tx_count[DATA_BITS * 2+:DATA_BITS];
                        'h207: PRDATA <= tx_count[DATA_BITS * 3+:DATA_BITS];

                        'h208: PRDATA <= tx_next[DATA_BITS * 0+:DATA_BITS];
                        'h209: PRDATA <= tx_next[DATA_BITS * 1+:DATA_BITS];

                        'h210: PRDATA <= cts_deactivate_delay[DATA_BITS * 0+:DATA_BITS];
                        'h211: PRDATA <= cts_deactivate_delay[DATA_BITS * 1+:DATA_BITS];
                        'h212: PRDATA <= cts_deactivate_delay[DATA_BITS * 2+:DATA_BITS];
                        'h213: PRDATA <= cts_deactivate_delay[DATA_BITS * 3+:DATA_BITS];

                        'h214: PRDATA <= tx_delay[DATA_BITS * 0+:DATA_BITS];
                        'h215: PRDATA <= tx_delay[DATA_BITS * 1+:DATA_BITS];
                        'h216: PRDATA <= tx_delay[DATA_BITS * 2+:DATA_BITS];
                        'h217: PRDATA <= tx_delay[DATA_BITS * 3+:DATA_BITS];

                        default: PRDATA <= 0;
                    endcase
                end
            end


        end
    end

endmodule
