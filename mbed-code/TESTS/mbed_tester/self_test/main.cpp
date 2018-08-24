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

#include "MbedTester.h"
#include "pinmap.h"

#define TESTER_REMAP                    0x00001000
#define TESTER_PERIPHERAL_SELECT        0x00100000
#define TESTER_GPIO                     0x00101000
#define PHYSICAL_PINS                   128
#define LOGICAL_PINS                    8

const PinList *form_factor = pinmap_ff_default_pins();
const PinList *restricted = pinmap_restricted_pins();
MbedTester tester(form_factor, restricted);

void self_test()
{
    tester.reset();
    TEST_ASSERT(tester.self_test_all());
}

void led_test()
{
    uint8_t data;
    tester.reset();

    // Map all pins to nothing
    for (int i = 0; i < PHYSICAL_PINS + LOGICAL_PINS; i++) {
        data = 0xFF;
        tester.write(TESTER_REMAP + i, &data, sizeof(data));
    }

    // Select GPIO
    data = 1;
    tester.write(TESTER_PERIPHERAL_SELECT, &data, sizeof(data));

    // Map first 8 leds
    for (int i = 0; i < 8; i++) {
        // Physical remap
        data = i;
        tester.write(TESTER_REMAP + 48 + i, &data, sizeof(data));
        // Logical remap
        data = 48 + i;
        tester.write(TESTER_REMAP + PHYSICAL_PINS + i, &data, sizeof(data));
    }

    // Light each up 1 by 1
    for (int i = 0; i < 8; i++) {
        data = 3;
        tester.write(TESTER_GPIO + i, &data, sizeof(data));
        wait_ms(50);
        data = 2;
        tester.write(TESTER_GPIO + i, &data, sizeof(data));
        wait_ms(50);
    }

    // Reverse map first 8 leds
    for (int i = 0; i < 8; i++) {
        // Physical remap
        data = 7 - i;
        tester.write(TESTER_REMAP + 48 + i, &data, sizeof(data));
        // Logical remap
        data = 48 + i;
        tester.write(TESTER_REMAP + PHYSICAL_PINS + 7 - i, &data, sizeof(data));
    }

    // Light each up 1 by 1
    for (int i = 0; i < 8; i++) {
        data = 3;
        tester.write(TESTER_GPIO + i, &data, sizeof(data));
        wait_ms(50);
        data = 2;
        tester.write(TESTER_GPIO + i, &data, sizeof(data));
        wait_ms(50);
    }

    // Turn all pins to Hi-Z
    for (int i = 0; i < 8; i++) {
        data = 0;
        tester.write(TESTER_GPIO + i, &data, sizeof(data));
    }
}

void button_test()
{
    uint8_t data;
    tester.reset();

    // Map first 8 buttons
    for (int i = 0; i < 8; i++) {
        // Physical remap
        data = i;
        tester.write(TESTER_REMAP + 32 + i, &data, sizeof(data));
        // Logical remap
        data = 32 + i;
        tester.write(TESTER_REMAP + PHYSICAL_PINS + i, &data, sizeof(data));
    }

    // Display button state
    printf("Press buttons\r\n");
    uint8_t pins_prev = 0;
    for (int i = 0; i < 100; i++) {
        uint8_t pins = 0;
        for (int j = 0; j < 8; j++) {
            tester.read(TESTER_GPIO + j, &data, sizeof(data));
            pins |= data > 0 ? (1 << j) : 0;
        }

        if (pins != pins_prev) {
            printf("Change to ");
            for (int j = 0; j < 8; j++) {
                bool one = pins & (1 << (7 - j));
                putchar(one ? '1' : '0');
            }
            printf("\r\n");
            pins_prev = pins;
        }
        wait_ms(10);
    }
}

void metrics_test()
{
    tester.reset();

    // Pick a pin in the form factor
    PinName pin = NC;
    for (size_t i = 0; i < form_factor->count; i++) {
        if (pinmap_list_has_pin(restricted, form_factor->pins[i])) {
            continue;
        }
        pin = form_factor->pins[i];
        break;
    }
    TEST_ASSERT_NOT_EQUAL(NC, pin);

    uint32_t start_delay = 100000;
    uint32_t middle_delay = 1000;
    uint32_t end_delay = 50000;

    for (int i = 0; i < MbedTester::LogicalPinCount; i++) {
        tester.pin_map_reset();
        tester.pin_map_set(pin, (MbedTester::LogicalPin)(MbedTester::LogicalPinIOMetrics0 + i));
        DigitalOut out(pin, 0);

        core_util_critical_section_enter();
        tester.io_metrics_start();

        // Low
        wait_us(start_delay);

        // High pulse
        out = 1;
        wait_us(middle_delay);
        out = 0;

        // Low
        wait_us(end_delay);

        tester.io_metrics_stop();
        core_util_critical_section_exit();

        for (int j = 0; j < MbedTester::LogicalPinCount; j++) {
            MbedTester::LogicalPin cur = (MbedTester::LogicalPin)(MbedTester::LogicalPinIOMetrics0 + j);
            if (j == i) {

                printf("Channel %i\r\n", i);
                printf("Minimum pulse low %lu us\r\n", tester.io_metrics_min_pulse_low(cur) / 100);
                printf("Minimum pulse high %lu us\r\n", tester.io_metrics_min_pulse_high(cur) / 100);
                printf("Maximum pulse low %lu us\r\n", tester.io_metrics_max_pulse_low(cur) / 100);
                printf("Maximum pulse high %lu us\r\n", tester.io_metrics_max_pulse_high(cur) / 100);
                printf("Rising edges %lu\r\n", tester.io_metrics_rising_edges(cur));
                printf("Falling edges %lu\r\n", tester.io_metrics_falling_edges(cur));

                TEST_ASSERT_EQUAL(0xFFFFFFFF, tester.io_metrics_min_pulse_low(cur));
                TEST_ASSERT_UINT32_WITHIN(20, start_delay, tester.io_metrics_max_pulse_low(cur) / 100);
                TEST_ASSERT_UINT32_WITHIN(20, middle_delay, tester.io_metrics_min_pulse_high(cur) / 100);
                TEST_ASSERT_UINT32_WITHIN(20, middle_delay, tester.io_metrics_max_pulse_high(cur) / 100);
                TEST_ASSERT_EQUAL(1, tester.io_metrics_rising_edges(cur));
                TEST_ASSERT_EQUAL(1, tester.io_metrics_falling_edges(cur));

            } else {

                TEST_ASSERT_EQUAL(0xFFFFFFFF, tester.io_metrics_min_pulse_low(cur));
                TEST_ASSERT_EQUAL(0xFFFFFFFF, tester.io_metrics_min_pulse_high(cur));
                TEST_ASSERT(tester.io_metrics_max_pulse_low(cur) / 100 >= start_delay + middle_delay + end_delay);
                TEST_ASSERT_EQUAL(0, tester.io_metrics_max_pulse_high(cur));
                TEST_ASSERT_EQUAL(0, tester.io_metrics_rising_edges(cur));
                TEST_ASSERT_EQUAL(0, tester.io_metrics_falling_edges(cur));
            }
        }
    }
}

Case cases[] = {
    Case("MbedTester - self test", self_test),
    Case("MbedTester - led test", led_test),
    Case("MbedTester - button test", button_test),
    Case("MbedTester - metrics tester", metrics_test)
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
