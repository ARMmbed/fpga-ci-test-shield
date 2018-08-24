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

`ifdef __ICARUS__
`define util_assert(cond) if (!(cond)) begin $display("%0t Assert failed - Expression '%s' evaluated to false on line %0d of %s", $time, "cond", `__LINE__, `__FILE__); $finish_and_return(-1); end
`define util_assert_display(cond, args) if (!(cond)) begin $display("%0t Assert failed - Expression '%s' evaluated to false on line %0d of %s", $time, "cond", `__LINE__, `__FILE__);  $display args; $finish_and_return(-1); end
`define util_assert_equal(expected, actual) if ((expected) !== (actual)) begin $display("%0t Assert failed - Expected %0d got %0d on line %0d of %s", $time, expected, actual, `__LINE__, `__FILE__); $finish_and_return(-1); end
`else
`define util_assert(cond) if (!(cond)) begin $display("%0t Assert failed - Expression evaluated to false", $time); $finish(1); end
`define util_assert_display(cond, args) if (!(cond)) begin $display("%0t Assert failed - Expression evaluated to false", $time); $display args ; $finish(1); end
`define util_assert_equal(expected, actual) if ((expected) !== (actual)) begin $display("%0t Assert failed - Expected %0d got %0d", $time, expected, actual); $finish(1); end
`endif
