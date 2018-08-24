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

#include "utest/utest.h"
#include "unity/unity.h"
#include "greentea-client/test_env.h"
#include "mbed.h"

using namespace utest::v1;

#include "UARTTester.h"
#include "pinmap.h"
#include "serial_api.h"

const PinList *form_factor = pinmap_ff_default_pins();
const PinList *restricted = pinmap_restricted_pins();
UARTTester tester(form_factor, restricted);

void uart_test()
{
    PinName tx = NC;
    PinName rx = NC;
    PinName cts = NC;
    PinName rts = NC;

    const PinMap *const maps[] = {
        serial_tx_pinmap(),
        serial_rx_pinmap(),
        serial_cts_pinmap(),
        serial_rts_pinmap()
    };
    PinName *pins[] = {
        &tx,
        &rx,
        &cts,
        &rts
    };

    for (const PinMap *map = serial_tx_pinmap(); map->pin != NC; map++) {
        if (pinmap_list_has_pin(restricted, map->pin)) {
            continue;
        }
        if (!pinmap_list_has_pin(form_factor, map->pin)) {
            continue;
        }
        tx = map->pin;
        if (!pinmap_find_peripheral_pins(form_factor, restricted, map->peripheral, maps, pins, sizeof(maps) / sizeof(maps[0]))) {
            tx = NC;
            continue;
        }
        break;
    }
    printf("Pin = %s\r\n", pinmap_ff_default_pin_to_string(tx));
    TEST_ASSERT_NOT_EQUAL(NC, tx);

    tester.reset();
    tester.pin_map_set(tx, MbedTester::LogicalPinUARTRx);
    tester.pin_map_set(rx, MbedTester::LogicalPinUARTTx);
    tester.pin_map_set(cts, MbedTester::LogicalPinUARTRts);
    tester.pin_map_set(rts, MbedTester::LogicalPinUARTCts);

    serial_t serial;
    serial_init(&serial, tx, rx);
    serial_baud(&serial, 9600);

    printf("Setting up tester\r\n");
    tester.peripherals_reset();
    tester.select_peripheral(MbedTester::PeripheralUART);
    tester.set_baud(9600);
    tester.set_bits(8);
    tester.set_stops(1);
    tester.set_parity(false, false);
    tester.rx_start();

    /* Test FPGA RX */

    printf("Sending data\r\n");
    wait(0.1);
    serial_putc(&serial, 27);
    wait(0.1);

    tester.rx_stop();

    uint16_t data = tester.rx_get_data();
    printf("Uart Data %lu\r\n", data);
    printf("Uart checksum 0x%x\r\n", tester.rx_get_checksum());
    printf("Uart count %lu\r\n", tester.rx_get_count());
    printf("Uart framing errors %lu\r\n", tester.rx_get_framing_errors());
    printf("Uart parity errors %lu\r\n", tester.rx_get_parity_errors());
    printf("Uart stop errors %lu\r\n", tester.rx_get_stop_errors());
    TEST_ASSERT_EQUAL(27, data);
    TEST_ASSERT_EQUAL(27, tester.rx_get_checksum());
    TEST_ASSERT_EQUAL(1, tester.rx_get_count());
    TEST_ASSERT_EQUAL(0, tester.rx_get_framing_errors());
    TEST_ASSERT_EQUAL(0, tester.rx_get_parity_errors());
    TEST_ASSERT_EQUAL(0, tester.rx_get_stop_errors());

    /* Test FPGA TX */

    tester.tx_set_count(2);
    tester.tx_set_next(12);

    tester.tx_start();

    int c1 = serial_getc(&serial);
    int c2 = serial_getc(&serial);

    tester.tx_stop();
    printf("C1 %i C2 %i\r\n", c1, c2);
    TEST_ASSERT_EQUAL(12, c1);
    TEST_ASSERT_EQUAL(13, c2);

    serial_free(&serial);
    tester.peripherals_reset();
}

Case cases[] = {
    Case("UARTTester - self test", uart_test)
};

utest::v1::status_t greentea_test_setup(const size_t number_of_cases)
{
    GREENTEA_SETUP(60, "default_auto");
    return greentea_test_setup_handler(number_of_cases);
}

Specification specification(greentea_test_setup, cases, greentea_test_teardown_handler);

int main()
{
    Harness::run(specification);
}
