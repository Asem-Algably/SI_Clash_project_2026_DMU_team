# Questa Coverage Exclusions / Waivers for coarse
# Generated for verified unreachable RTL code, defensive saturation clamps, and constant/padding toggle bits.
# NOTE: Covergroups and SVA assertions/directives remain 100% active.

# 1. Exclude UVM testbench / harness code coverage (keep covergroups and SVA assertions active)
coverage exclude -du work.coarse_cfo_core_inter -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.sva -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.top -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_sequence_item -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.directed_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.golden_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.reset_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_scoreborad_pck -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_coverage_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_monitor -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_sequencer -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_configuration -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_drive -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_agtt -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_env_pac -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.coarse_cfo_core_test_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}

# 2. DUT Behavioral/Code Coverage Waivers
# Accumulator loop termination invariant (active_q clears at count_q == 32 = WinLen)
coverage exclude -scope /top/dut/u_accumulator -feccondrow 60 5 -comment {active_q clears at WinLen=32; (count_q < 32)_0 unreachable}

# CORDIC unreachable default arms and redundant cascading else-if sign FEC rows
coverage exclude -scope /top/dut/u_cordic_angle -linerange 73 173 -code bs -comment {Unreachable default case arms for synthesis/lint safety}
coverage exclude -scope /top/dut/u_cordic_angle -feccondrow 163 3 -comment {Cascading else-if: (~sign_x_q && ~sign_y_q) intercepted at L161}
coverage exclude -scope /top/dut/u_cordic_angle -feccondrow 165 1 -comment {Cascading else-if: sign_x_q=0 intercepted at L161/L163}

# 3. Structural Zero-Toggle / Constant Tie-Off / Zero-Padding Bit Waivers
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_d[35] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_d[36] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_d[37] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_d[38] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_d[39] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_q[35] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_q[36] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_q[37] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_q[38] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_cordic_angle -togglenode x_q[39] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode force_cfo_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode force_cfo_i[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
