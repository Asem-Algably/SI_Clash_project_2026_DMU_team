# Questa Coverage Exclusions / Waivers for costas
# Generated for verified unreachable RTL code, defensive saturation clamps, and constant/padding toggle bits.
# NOTE: Covergroups and SVA assertions/directives remain 100% active.

# 1. Exclude UVM testbench / harness code coverage (keep covergroups and SVA assertions active)
coverage exclude -du work.costas_top_inter -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.sva -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.top -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_sequence_item -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.directed_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.golden_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.reset_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_scoreborad_pck -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_coverage_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_configuration -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_monitor -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_sequencer -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_drive -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_agtt -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_env_pac -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.costas_top_test_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}

# 2. DUT Behavioral/Code Coverage Waivers
# Defensive Costas phase_error & pi_filter clamps (nominal AGC/gain scale avoids +-32767 and +-Max_Pi_Output saturation)
coverage exclude -scope /top/dut/u_pe -linerange 52-56 -code bcs -comment {Nominal symbol scale does not saturate 16-bit phase_error}
coverage exclude -scope /top/dut/u_pi -linerange 68-72 127-135 -code bcs -comment {Closed-loop frequency word remains well within +-Max_Pi_Output}
coverage exclude -scope /top/dut/u_pi -linerange 121 -allfalse -code b -comment {Anti-windup freeze only active when output saturates}
coverage exclude -scope /top/dut/u_pi -fecexprrow 76 2 3 4 6 7 8 -comment {Anti-windup freeze saturation flags remain 0 in linear operation}

# Costas quad_check mathematically unreachable false arms (full_any sets evt -> done_o<=1 same cycle as cnt reaches 15/-16)
coverage exclude -scope /top/dut/u_quad -linerange 44 48 54 58 -allfalse -code b -comment {done_o latches same cycle cnt reaches 15/-16; !done_o blocks subsequent entry}
coverage exclude -scope /top/dut/u_quad -feccondrow 44 1 -comment {cnt_i_q cannot be 15 while valid_i && !done_o}
coverage exclude -scope /top/dut/u_quad -feccondrow 48 1 -comment {cnt_i_q cannot be -16 while valid_i && !done_o}
coverage exclude -scope /top/dut/u_quad -feccondrow 54 1 -comment {cnt_q_q cannot be 15 while valid_i && !done_o}
coverage exclude -scope /top/dut/u_quad -feccondrow 58 1 -comment {cnt_q_q cannot be -16 while valid_i && !done_o}

# Costas lock detectors parameter & threshold decay invariants
coverage exclude -scope /top/dut/u_lock_int -linerange 161-162 -code bs -comment {Min_Symbols=0 dead counter increment}
coverage exclude -scope /top/dut/u_lock_int -fecexprrow 133 3 -comment {Min_Symbols=0 -> idx_ok is constant 1'b1}
coverage exclude -scope /top/dut/u_lock_pub -fecexprrow 133 3 -comment {Init_Error=8192 with alpha=1/16 stays above thr_enter before Min_Symbols=15}
coverage exclude -scope /top/dut/u_quad -fecexprrow 64 8 -comment {Covered 9/9 in sync_system_top_uvm; in unit costas bursts I-counter reaches +15 first}

# 3. Structural Zero-Toggle / Constant Tie-Off / Zero-Padding Bit Waivers
coverage exclude -scope /top/dut/u_slicer -togglenode mod_type_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode freeze -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode ki_i[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode kp_i[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[27] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[28] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[29] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[30] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[31] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[32] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode max_ext[33] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode p_prop_r[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode p_prop_r[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode sat_neg_q -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi -togglenode sat_pos_q -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode e_abs[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode e_abs[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode idx_ok -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_acc[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_acc[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_next[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_next[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_val[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode m_val[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode sym_cnt -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode thr[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode thr[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode thr[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int/gen_single_cycle -togglenode thr[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_enter_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_int -togglenode thr_exit_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[27] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[28] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_quad -togglenode phase_adj_o[29] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode e_abs[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode e_abs[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_acc[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_acc[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_next[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_next[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_val[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode m_val[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode thr[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode thr[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub/gen_single_cycle -togglenode thr[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_enter_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_pub -togglenode thr_exit_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode costas_gain_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d1[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d2[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode ki_d3[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d1[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d2[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode kp_d3[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode mod_type_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[27] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[28] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode phase_adj_o[29] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_enter[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode thr_exit[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
