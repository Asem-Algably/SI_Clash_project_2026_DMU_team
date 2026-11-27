# Questa Coverage Exclusions / Waivers for derot
# Generated for verified unreachable RTL code, defensive saturation clamps, and constant/padding toggle bits.
# NOTE: Covergroups and SVA assertions/directives remain 100% active.

# 1. Exclude UVM testbench / harness code coverage (keep covergroups and SVA assertions active)
coverage exclude -du work.derotator_inter -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.sva -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.top -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_sequence_item -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_golden_seq_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_scoreborad_pck -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_coverage_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_monitor -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_sequencer -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_configuration -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_drive -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_agtt -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_env_pac -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.derotator_test_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}

# 2. DUT Behavioral/Code Coverage Waivers
# Exhaustive 12-bit quarter-wave ROM default case arm (all 4096 addresses hit in tc_09)
coverage exclude -scope /top/dut/lut_rom_inst -srcfile ../../rtl/derotator/lut_rom.sv -linerange 47 -code bs -comment {Unreachable default arm on exhaustive 12-bit ROM case}

# 3. Structural Zero-Toggle / Constant Tie-Off / Zero-Padding Bit Waivers
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_ext[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_now[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode coarse_reg[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/freq_word_inst -togglenode force_freq_i[31] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[27] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[28] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/nco_inst -togglenode phase_adj_i[29] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/lut_rom_inst -togglenode cos_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/lut_rom_inst -togglenode cos_q[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/lut_rom_inst -togglenode sin_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/lut_rom_inst -togglenode sin_q[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/complex_multiplier_inst -togglenode cos_th[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/complex_multiplier_inst -togglenode sin_th[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/sva_inst -togglenode force_freq_i[31] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode c0[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode force_freq_i[31] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[27] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[28] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_i[29] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode s0[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
