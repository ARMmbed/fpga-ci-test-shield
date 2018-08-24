# FPGA CI Test Shield

This project contains RTL and tests for the FPGA CI Test Shield. The FPGA CI Test Shield is a shield which can be attached to Mbed boards to allow in-depth testing of all connected pins.

## Required software and hardware

Building and testing this project require the following tools and hardware:
 - [Vivado HL WebPACK](https://www.xilinx.com/products/design-tools/vivado/vivado-webpack.html) for FPGA synthesis, implementation and programming
 - [iverilog](http://iverilog.icarus.com/) for simulation testing
 - [GTKWave](http://gtkwave.sourceforge.net/) for viewing simulation waveforms
 - FPGA CI Test Shield
 - Any Mbed enabled board

## Simulation testing

Batch files are provided to run simulation on various parts of the system. To run the tests, open a terminal in the `sim` directory and run the `build_and_run_*.bat` for the desired test. If an error occurs, it will be printed. Note - this also starts a waveform viewer at the end of the simulation.

## Building and programming the FPGA image

Vivado is used to build FPGA images. The following sequence can be used to create a programmable image:
 - Generate and open the project
    - Start Vivado
    - Click "Window -> Tcl Console"
    - In the Tcl console, change the current directory to that of the project `> cd <project location>/fpga-ci-test-shield` (for those using Windows, Vivado uses forward slashes instead of backslashes for file paths)
    - In the Tcl console, generate and open the project `> source generate_project_shield.tcl`
 - Generate bitstream (.bit and .bin files) inside Vivado by clicking the `Generate Bitstream` button
 - Add a CRC to the new image
    - Start command prompt in the project directory
    - Run the post process script `> python post_process_bitstream.py project_shield\project_shield.runs\impl_1\mbed_tester_shield_top.bin mbed_tester_shield_top_crc.bin`
 - Program the bitstream file to the device using the update script and Mbed code found in the [fpga-ci-test-shield-updater](https://github.com/ARMmbed/fpga-ci-test-shield-updater) project.

## Example greentea testcase using FPGA CI test shield

```C++
void spi_test_common(PinName mosi, PinName miso, PinName sclk, PinName ssel)
{
    printf("SPI test on mosi=%s (%i), miso=%s (%i), sclk=%s (%i), ssel=%s (%i)\r\n",
            pinmap_ff_default_pin_to_string(mosi), mosi,
            pinmap_ff_default_pin_to_string(miso), miso,
            pinmap_ff_default_pin_to_string(sclk), sclk,
            pinmap_ff_default_pin_to_string(ssel), ssel);

    // Remap pins for test
    tester.reset();
    tester.pin_map_set(mosi, MbedTester::LogicalPinSPIMosi);
    tester.pin_map_set(miso, MbedTester::LogicalPinSPIMiso);
    tester.pin_map_set(sclk, MbedTester::LogicalPinSPISclk);
    tester.pin_map_set(ssel, MbedTester::LogicalPinSPISsel);

    // Initialize mbed SPI pins
    spi_t spi;
    spi_init(&spi, mosi, miso, sclk, ssel);
    spi_format(&spi, 8, 0, 0);
    spi_frequency(&spi, 1000000);

    // Reset tester stats and select SPI
    tester.peripherals_reset();
    tester.select_peripheral(MbedTester::SPI);

    // Send and receive test data
    uint32_t checksum = 0;
    for (int i = 0; i < TRANSFER_COUNT; i++) {
        uint8_t data = spi_master_write(&spi, (0 - i) & 0xFF);
        TEST_ASSERT_EQUAL(i & 0xFF, data);

        checksum += (0 - i) & 0xFF;
    }

    // Verify that the transfer was successful
    TEST_ASSERT_EQUAL(TRANSFER_COUNT, tester.spi_transfer_count());
    TEST_ASSERT_EQUAL(checksum, tester.spi_to_slave_checksum());

    printf("  Pin combination works\r\n");

    spi_free(&spi);
    tester.reset();
}
```

## License and contributions

The software is provided under the [Apache-2.0 license](https://github.com/ARMmbed/mbed-os/blob/master/LICENSE-apache-2.0.txt). Contributions to this project are accepted under the same license. Please see [contributing.md](https://github.com/ARMmbed/mbed-os/blob/master/CONTRIBUTING.md) for more information.

This project contains code from other projects. The original license text is included in those source files. They must comply with our [license guide](https://os.mbed.com/docs/mbed-os/latest/contributing/license.html).

Folders containing files under different permissive license than Apache 2.0 are listed in the [LICENSE](https://github.com/ARMmbed/mbed-os/blob/master/LICENSE.md) file.
