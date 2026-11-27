# Questa Coverage Exclusions / Waivers for str
# Generated for verified unreachable RTL code, defensive saturation clamps, and constant/padding toggle bits.
# NOTE: Covergroups and SVA assertions/directives remain 100% active.

# 1. Exclude UVM testbench / harness code coverage (keep covergroups and SVA assertions active)
coverage exclude -du work.str_top_inter -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.top -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_sequence_item -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.main_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.golden_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.reset_sequence -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_scoreborad_pck -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_coverage_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_configuration -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_monitor_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_sequencer -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_drive -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_agtt -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_env_pac -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}
coverage exclude -du work.str_top_test_pkg -code bcefst -comment {Testbench/UVM harness excluded from RTL code coverage}

# 2. DUT Behavioral/Code Coverage Waivers
# Defensive STR PI saturation clamps & anti-windup (closed-loop error stays below +-MAX_V_PI = +-9395241)
coverage exclude -scope /top/dut/u_pi_loop -linerange 86-89 102 103 106-109 124-127 -code bces -comment {Closed-loop STR never winds PI loop to +-MAX_V_PI clamp}

# Modulo-1 controller upper clamp (mu_full >= 1.0 cannot be reached with standalone str_uvm stimulus; covered in sync_system_top_uvm tc_30)
coverage exclude -scope /top/dut/u_modulo_ctrl -linerange 160-161 -code bcs -comment {Modulo-1 residual mu_full remains below 1.0 threshold in standalone str_uvm}

# STR lock_detector structural invariants (clr_i=0 tie-off, unsigned sym_cnt>=0, Min_Symbols=1 idx_ok_r==0 with Init_Error>thr)
coverage exclude -scope /top/dut/u_lock_detector -feccondrow 48 4 -comment {clr_i tied to 1'b0 in str_top}
coverage exclude -scope /top/dut/u_lock_detector -feccondrow 58 4 -comment {clr_i tied to 1'b0 in str_top}
coverage exclude -scope /top/dut/u_lock_detector -feccondrow 81 4 -comment {clr_i tied to 1'b0 in str_top}
coverage exclude -scope /top/dut/u_lock_detector -fecexprrow 63 1 -comment {Unsigned sym_cnt >= 0 is always true}
coverage exclude -scope /top/dut/u_lock_detector -fecexprrow 68 3 -comment {Init_Error > thr until idx_ok_r sets on symbol 0}

# 3. Structural Zero-Toggle / Constant Tie-Off / Zero-Padding Bit Waivers
coverage exclude -scope /top/dut/u_i_interp -togglenode a12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_aligned[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_aligned[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_aligned[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_aligned[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_s1[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode b_s2[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode c12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_i_interp -togglenode d12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode a12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_aligned[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_aligned[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_aligned[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_aligned[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_s1[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode b_s2[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode c12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_q_interp -togglenode d12[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi_loop -togglenode sat_hi -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_pi_loop -togglenode sat_lo -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_4x_q1[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_4x_q1[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_4x_q2[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_4x_q2[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_raw[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode eta_raw_q[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode w_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode w_val[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode force_w_full[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_modulo_ctrl -togglenode w_eff[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode clr_i -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode e_abs_r[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode e_abs_r[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode e_abs_r[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode e_abs_r[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_acc[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_acc[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_acc[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_acc[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_acc[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_next[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_next[23] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_next[24] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_next[25] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_next[26] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_val_r[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_val_r[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_val_r[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_val_r[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode m_val_r[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector/gen_pipelined -togglenode thr[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_enter_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[8] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[9] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[10] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[11] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[12] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[13] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[14] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[16] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[17] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[18] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[19] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[20] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[21] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut/u_lock_detector -togglenode thr_exit_i[22] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode force_w_i[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[0] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[1] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[2] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[3] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[4] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[5] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[6] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode loop_gain_i[7] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode w_mux[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode w_o[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
coverage exclude -scope /top/dut -togglenode w_val[15] -comment {Structural constant tie-off, zero-padding, or bounded MSB/LSB bit}
