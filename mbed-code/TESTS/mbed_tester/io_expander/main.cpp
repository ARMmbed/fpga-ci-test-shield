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

#if !defined(FULL_TEST_SHIELD)
#error [NOT_SUPPORTED] The IO Expander test does not run on prototype hardware
#endif

#include "utest/utest.h"
#include "unity/unity.h"
#include "greentea-client/test_env.h"
#include "mbed.h"

using namespace utest::v1;

#include "MbedTester.h"
#include "pinmap.h"

const PinList *form_factor = pinmap_ff_default_pins();
const PinList *restricted = pinmap_restricted_pins();
MbedTester tester(form_factor, restricted);

void io_expander_test()
{
    printf("Testing IO expander\r\n");

    // Reset tester stats and select GPIO
    tester.peripherals_reset();

    // Select GPIO peripheral
    tester.select_peripheral(MbedTester::PeripheralGPIO);

    // Remap pins for test
    tester.reset();

    //reset IO expander
    tester.pin_pull_reset_all();

    // IO Expander Test using the system i2c bus
    for (uint32_t i = 0; i < form_factor->count; i++) {
        const PinName test_pin = form_factor->pins[i];
        if (pinmap_list_has_pin(restricted, test_pin)) {
            printf("Skipping pin %s (%i)\r\n", pinmap_ff_default_pin_to_string(test_pin), test_pin);
            continue;
        }

        printf("IO Expander i2c system bus test on pin %s (%i)\r\n", pinmap_ff_default_pin_to_string(test_pin), test_pin);

        //test pulldown
        tester.pin_set_pull(test_pin, MbedTester::PullDown);
        TEST_ASSERT_EQUAL(0, tester.io_expander_read(test_pin, MbedTester::RegConfig));//config bit should be 0 for output
        TEST_ASSERT_EQUAL(0, tester.io_expander_read(test_pin, MbedTester::RegOutput));//output bit should be 0

        //test pullup
        tester.pin_set_pull(test_pin, MbedTester::PullUp);
        TEST_ASSERT_EQUAL(0, tester.io_expander_read(test_pin, MbedTester::RegConfig));//config bit should be 0 for output
        TEST_ASSERT_EQUAL(1, tester.io_expander_read(test_pin, MbedTester::RegOutput));//output bit should be 1

        //test tristate
        tester.pin_set_pull(test_pin, MbedTester::PullNone);
        TEST_ASSERT_EQUAL(1, tester.io_expander_read(test_pin, MbedTester::RegConfig));//config bit should be 1 for input

        tester.pin_map_set(test_pin, MbedTester::LogicalPinGPIO0);
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 0, true);//write a 0 to the test_pin
        TEST_ASSERT_EQUAL(0, tester.io_expander_read(test_pin, MbedTester::RegInput));//input bit should be 0
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 1, true);//write a 1 to the test_pin
        TEST_ASSERT_EQUAL(1, tester.io_expander_read(test_pin, MbedTester::RegInput));//input bit should be 1
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 0, false);//un-drive the test_pin

        TEST_ASSERT_EQUAL(1, tester.self_test_control_current());//assert control channel still functioning properly
    }

    // IO Expander Test using bit banged i2c over the control channel
    for (uint32_t i = 0; i < form_factor->count; i++) {
        const PinName test_pin = form_factor->pins[i];
        if (pinmap_list_has_pin(restricted, test_pin)) {
            printf("Skipping pin %s (%i)\r\n", pinmap_ff_default_pin_to_string(test_pin), test_pin);
            continue;
        }

        printf("IO Expander control channel bit bang test on pin %s (%i)\r\n", pinmap_ff_default_pin_to_string(test_pin), test_pin);

        //test pulldown
        tester.pin_set_pull_bb(test_pin, MbedTester::PullDown);
        TEST_ASSERT_EQUAL(0, tester.io_expander_read_bb(test_pin, MbedTester::RegConfig));//config bit should be 0 for output
        TEST_ASSERT_EQUAL(0, tester.io_expander_read_bb(test_pin, MbedTester::RegOutput));//output bit should be 0

        //test pullup
        tester.pin_set_pull_bb(test_pin, MbedTester::PullUp);
        TEST_ASSERT_EQUAL(0, tester.io_expander_read_bb(test_pin, MbedTester::RegConfig));//config bit should be 0 for output
        TEST_ASSERT_EQUAL(1, tester.io_expander_read_bb(test_pin, MbedTester::RegOutput));//output bit should be 1

        //test tristate
        tester.pin_set_pull_bb(test_pin, MbedTester::PullNone);
        TEST_ASSERT_EQUAL(1, tester.io_expander_read_bb(test_pin, MbedTester::RegConfig));//config bit should be 1 for input

        tester.pin_map_set(test_pin, MbedTester::LogicalPinGPIO0);
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 0, true);//write a 0 to the test_pin
        TEST_ASSERT_EQUAL(0, tester.io_expander_read_bb(test_pin, MbedTester::RegInput));//input bit should be 0
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 1, true);//write a 1 to the test_pin
        TEST_ASSERT_EQUAL(1, tester.io_expander_read_bb(test_pin, MbedTester::RegInput));//input bit should be 1
        tester.gpio_write(MbedTester::LogicalPinGPIO0, 0, false);//un-drive the test_pin

        TEST_ASSERT_EQUAL(1, tester.self_test_control_current());//assert control channel still functioning properly
    }
}

utest::v1::status_t setup(const Case *const source, const size_t index_of_case)
{
    tester.reset();

    return greentea_case_setup_handler(source, index_of_case);
}

utest::v1::status_t teardown(const Case *const source, const size_t passed, const size_t failed,
                                                      const failure_t reason)
{
    return greentea_case_teardown_handler(source, passed, failed, reason);
}

Case cases[] = {
    Case("IO Expander", setup, io_expander_test, teardown),
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
