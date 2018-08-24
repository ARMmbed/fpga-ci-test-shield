#
# Copyright (c) 2019, Arm Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from argparse import ArgumentParser, FileType
from binascii import crc32
from struct import pack


def main():
    parser = ArgumentParser(description='FPGA CI Test Shield Firmware post-processing tool')
    parser.add_argument('src', type=FileType("rb"), help="Binary FPGA image to post-process")
    parser.add_argument('dst', type=FileType("wb"), help="Location to write post-processed file")
    args = parser.parse_args()

    raw_src = args.src.read()
    args.src.close()
    print('File "%s" processed.' % args.src.name)

    size = len(raw_src)
    crc = crc32(raw_src) & 0xFFFFFFFF
    raw_size = pack("<I", size)
    raw_crc = pack("<I", crc)
    args.dst.write(raw_size + raw_src + raw_crc)
    args.dst.close()

    print('Output file "%s" written' % args.dst.name)
    print("    Size: %i" % size)
    print("    CRC: 0x%x" % crc)


if __name__ == "__main__":
    main()
