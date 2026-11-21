// ============================================================================
// File Name   : costas_pkg.sv
// Module Name : costas_pkg
// Author      : Arwa Kantoush
// Description : Verification package containing transaction definitions,
//               stimulus constraints, and functional coverage models for the
//               Costas Loop carrier recovery subsystem.
// ============================================================================
package costas_pkg;

    typedef enum logic [1:0] { HOLD = 2'b00, ACQ = 2'b01, TRACK = 2'b10 } mode_e;
    typedef enum logic [1:0] { QPSK = 2'b00, QAM16 = 2'b01 }             mod_e;

    class costas_transaction;

        // ------------------------------------------------------------------
        // Constants
        // ------------------------------------------------------------------
        parameter int QPSK_L  = 16384;            // QPSK level / 16-QAM outer level
        parameter int QAM_L   = 5461;             // 16-QAM inner level
        parameter int T2      = 2 * QAM_L;        // 16-QAM decision boundary (10922)
        parameter int NOISE   = 512;              // noise around ideal points
        parameter int MAX_PI  = 32'h1EB8_51EB;    // Max_Pi_Output
        parameter int PI_MID  = 32'h0010_0000;    // Mid-range threshold for PI filter
        parameter int E_MAX   = 32767;
        parameter int E_MIN   = -32768;

        // ------------------------------------------------------------------
        // Stimulus (inputs to DUT)
        // ------------------------------------------------------------------
        rand mode_e               mode;
        rand mod_e                mod_type;
        rand logic                valid, preamble_end, slicer_qpsk, ideal;
        rand logic signed [15:0]  i_sym, q_sym;

        // ------------------------------------------------------------------
        // Observed (set by the monitor before calling sample_out())
        // Note: Drive 'kp' from u_costas.kp_d3 in TB to align with freq_adj_valid
        // ------------------------------------------------------------------
        logic signed [15:0] e;
        logic               e_valid;
        logic signed [31:0] freq_adj, int_val;
        logic               freq_adj_valid;
        logic        [31:0] phase_adj;
        logic               phase_adj_valid;
        logic               lock, lock_int, quad_done, quad_unres;
        logic        [23:0] kp;

        // ------------------------------------------------------------------
        // Constraints
        // ------------------------------------------------------------------
        constraint c_mode {
            mode dist { HOLD := 10, ACQ := 45, TRACK := 45 };
        }

        constraint c_mod {
            mod_type dist { QPSK := 50, QAM16 := 50 };
        }

        constraint c_slicer {
            slicer_qpsk == (mode != TRACK);
        }

        constraint c_valid {
            valid dist { 1 := 85, 0 := 15 };
        }

        constraint c_pre {
            if (mode == HOLD) preamble_end == 0;
            else              preamble_end dist { 1 := 5, 0 := 95 };
        }

        constraint c_ideal_sel {
            ideal dist { 1 := 70, 0 := 30 };
        }

        constraint c_ideal_I {
            if (ideal) {
                if (mod_type == QPSK || slicer_qpsk) {
                    i_sym inside { [ QPSK_L-NOISE :  QPSK_L+NOISE],
                                   [-QPSK_L-NOISE : -QPSK_L+NOISE] };
                } else {
                    i_sym inside { [ QPSK_L-NOISE :  QPSK_L+NOISE],
                                   [-QPSK_L-NOISE : -QPSK_L+NOISE],
                                   [ QAM_L-NOISE  :  QAM_L+NOISE ],
                                   [-QAM_L-NOISE  : -QAM_L+NOISE ] };
                }
            }
        }

        constraint c_ideal_Q {
            if (ideal) {
                if (mod_type == QPSK || slicer_qpsk) {
                    q_sym inside { [ QPSK_L-NOISE :  QPSK_L+NOISE],
                                   [-QPSK_L-NOISE : -QPSK_L+NOISE] };
                } else {
                    q_sym inside { [ QPSK_L-NOISE :  QPSK_L+NOISE],
                                   [-QPSK_L-NOISE : -QPSK_L+NOISE],
                                   [ QAM_L-NOISE  :  QAM_L+NOISE ],
                                   [-QAM_L-NOISE  : -QAM_L+NOISE ] };
                }
            }
        }

        constraint c_corner_I {
            if (!ideal) {
                i_sym dist { 0 := 10,
                             T2 := 10, -T2 := 10,
                             T2+1 := 5, -(T2+1) := 5, T2-1 := 5, -(T2-1) := 5,
                             32767 := 10, -32768 := 10,
                             [-32768:32767] :/ 20 };
            }
        }

        constraint c_corner_Q {
            if (!ideal) {
                q_sym dist { 0 := 10,
                             T2 := 10, -T2 := 10,
                             T2+1 := 5, -(T2+1) := 5, T2-1 := 5, -(T2-1) := 5,
                             32767 := 10, -32768 := 10,
                             [-32768:32767] :/ 20 };
            }
        }

        // ==================================================================
        // Requirement_1: Mode / slicer-select coverage
        // Covergroup: cg_ctrl
        // ==================================================================
        covergroup cg_ctrl;
            cp_mode: coverpoint mode {
                bins hold  = {HOLD};
                bins acq   = {ACQ};
                bins track = {TRACK};
            }
            cp_mode_tr: coverpoint mode {
                bins hold_to_acq   = (HOLD  => ACQ);
                bins acq_to_track  = (ACQ   => TRACK);
                bins track_to_hold = (TRACK => HOLD);
            }
            cp_slq: coverpoint slicer_qpsk {
                bins qpsk_slicer = {1};
                bins qam_slicer  = {0};
            }
            cx_mode_slq: cross cp_mode, cp_slq {
                illegal_bins qam_slicer_not_track =
                    binsof(cp_slq.qam_slicer) && !binsof(cp_mode.track);
                illegal_bins qpsk_slicer_in_track =
                    binsof(cp_slq.qpsk_slicer) && binsof(cp_mode.track);
            }
        endgroup: cg_ctrl

        // ==================================================================
        // Requirement_2: valid / preamble_end coverage
        // Covergroup: cg_valid_pre
        // ==================================================================
        covergroup cg_valid_pre;
            cp_valid: coverpoint valid {
                bins v_1 = {1};
                bins v_0 = {0};
                bins gap_to_valid = (0 => 1);
                bins valid_to_gap = (1 => 0);
                bins long_gap     = (0 [* 3]);
            }
            cp_pre: coverpoint preamble_end iff (mode != HOLD) {
                bins pre_1 = {1};
                bins pre_0 = {0};
            }
        endgroup: cg_valid_pre

        // ==================================================================
        // Requirement_3: Input quadrant coverage across active modes
        // Covergroup: cg_sym
        // ==================================================================
        covergroup cg_sym;
            cp_quad: coverpoint {i_sym[15], q_sym[15]} iff (valid) {
                bins Q1 = {2'b00};
                bins Q2 = {2'b10};
                bins Q3 = {2'b11};
                bins Q4 = {2'b01};
            }
            cp_mode: coverpoint mode iff (valid) {
                bins acq   = {ACQ};
                bins track = {TRACK};
            }
            cx_quad_m: cross cp_quad, cp_mode;
        endgroup: cg_sym

        // ==================================================================
        // Requirement_4: all 16 QAM constellation points (slicer decisions)
        // Covergroup: cg_qam_points
        // ==================================================================
        covergroup cg_qam_points;
            cp_I_lvl: coverpoint i_sym iff (valid && mod_type == QAM16 && !slicer_qpsk) {
                bins I_outer_n = {[E_MIN : -(T2+1)]};
                bins I_inner_n = {[-T2  : -1]};
                bins I_inner_p = {[0    : T2-1]};
                bins I_outer_p = {[T2   : E_MAX]};
            }
            cp_Q_lvl: coverpoint q_sym iff (valid && mod_type == QAM16 && !slicer_qpsk) {
                bins Q_outer_n = {[E_MIN : -(T2+1)]};
                bins Q_inner_n = {[-T2  : -1]};
                bins Q_inner_p = {[0    : T2-1]};
                bins Q_outer_p = {[T2   : E_MAX]};
            }
            cx_qam16: cross cp_I_lvl, cp_Q_lvl;   // 16 constellation points
        endgroup: cg_qam_points

        // ==================================================================
        // Requirement_5: TED error (phase detector output)
        // Covergroup: cg_err
        // ==================================================================
        covergroup cg_err;
            cp_e: coverpoint e iff (e_valid) {
                bins neg_large = {[E_MIN : -2501]};
                bins neg_mid   = {[-2500 : -1025]};
                bins neg_small = {[-1024 : -1]};
                bins zero      = {0};
                bins pos_small = {[1     : 1024]};
                bins pos_mid   = {[1025  : 2500]};
                bins pos_large = {[2501  : E_MAX]};
            }
            cp_mode: coverpoint mode iff (e_valid) {
                bins acq   = {ACQ};
                bins track = {TRACK};
            }
            cx_e_mode: cross cp_e, cp_mode {
                ignore_bins zero_in_acq = binsof(cp_e.zero) && binsof(cp_mode.acq);
                ignore_bins large_in_track = (binsof(cp_e.pos_large) || binsof(cp_e.neg_large)) && binsof(cp_mode.track);
            }
        endgroup: cg_err

        // ==================================================================
        // Requirement_6: PI filter (gain select, output / integrator range)
        // Covergroup: cg_pi
        // ==================================================================
        covergroup cg_pi;
            cp_kp: coverpoint kp iff (freq_adj_valid) {
                bins kp_acq_qpsk = {24'd220364};
                bins kp_qam      = {24'd396656};
            }
            cp_freq: coverpoint freq_adj iff (freq_adj_valid) {
                bins neg_high = {[-MAX_PI : -PI_MID]};
                bins neg_low  = {[-PI_MID+1 : -1]};
                bins pos_low  = {[1 : PI_MID-1]};
                bins pos_high = {[PI_MID : MAX_PI]};
            }
            cp_int: coverpoint int_val iff (freq_adj_valid) {
                bins neg_high = {[-MAX_PI : -PI_MID]};
                bins neg_low  = {[-PI_MID+1 : -1]};
                bins pos_low  = {[1 : PI_MID-1]};
                bins pos_high = {[PI_MID : MAX_PI]};
            }
            cp_mode: coverpoint mode iff (freq_adj_valid) {
                bins acq   = {ACQ};
                bins track = {TRACK};
            }
            cx_kp_mode: cross cp_kp, cp_mode {
                illegal_bins kp_qam_acq =
                    binsof(cp_kp.kp_qam) && binsof(cp_mode.acq);
                illegal_bins kp_acq_track =
                    binsof(cp_kp.kp_acq_qpsk) && binsof(cp_mode.track);
            }
        endgroup: cg_pi

        // ==================================================================
        // Requirement_7: Lock detectors and quadrant check state
        // Covergroup: cg_lock
        // ==================================================================
        covergroup cg_lock;
            cp_lock: coverpoint lock {
                bins locked   = {1};
                bins unlocked = {0};
                bins rise     = (0 => 1);
                bins fall     = (1 => 0);
            }
            cp_lint: coverpoint lock_int {
                bins hi = {1};
                bins lo = {0};
            }
            cp_done: coverpoint quad_done {
                bins done     = {1};
                bins not_done = {0};
            }
            cp_unres: coverpoint quad_unres {
                bins unresolved = {1};
                bins ok         = {0};
            }
            cx_lock_state: cross cp_lock, cp_done, cp_unres {
                // Architecturally impossible states (lock_o = done && !unres && lock_pub)
                illegal_bins lock_without_done      = binsof(cp_lock.locked)      && binsof(cp_done.not_done);
                illegal_bins rise_lock_without_done = binsof(cp_lock.rise)        && binsof(cp_done.not_done);
                illegal_bins lock_with_unres        = binsof(cp_lock.locked)      && binsof(cp_unres.unresolved);
                illegal_bins rise_with_unres        = binsof(cp_lock.rise)        && binsof(cp_unres.unresolved);
                illegal_bins fall_with_unres        = binsof(cp_lock.fall)        && binsof(cp_unres.unresolved);
                illegal_bins unres_without_done     = binsof(cp_unres.unresolved) && binsof(cp_done.not_done);
                // Note: <fall, done, ok> is valid (lock loss via bucket during TRACK) and kept as target
            }
        endgroup: cg_lock

        // ==================================================================
        // Requirement_8: Phase-ambiguity resolution result (k * pi/2)
        // Covergroup: cg_quad
        // ==================================================================
        covergroup cg_quad;
            cp_adj: coverpoint phase_adj[31:30] iff (phase_adj_valid) {
                bins k0 = {2'b00};
                bins k1 = {2'b01};
                bins k2 = {2'b10};
                bins k3 = {2'b11};
            }
            cp_trig: coverpoint preamble_end iff (phase_adj_valid) {
                bins by_counter_full = {0};
                bins by_preamble_end = {1};
            }
            cx_adj_trig: cross cp_adj, cp_trig;
        endgroup: cg_quad

        // ------------------------------------------------------------------
        function new();
            cg_ctrl       = new();
            cg_valid_pre  = new();
            cg_sym        = new();
            cg_qam_points = new();
            cg_err        = new();
            cg_pi         = new();
            cg_lock       = new();
            cg_quad       = new();
        endfunction

        // Call with the stimulus about to be driven
        function void sample_in();
            cg_ctrl.sample();
            cg_valid_pre.sample();
            cg_sym.sample();
            cg_qam_points.sample();
        endfunction

        // Call from the monitor after the observed fields are updated
        function void sample_out();
            cg_err.sample();
            cg_pi.sample();
            cg_lock.sample();
            cg_quad.sample();
        endfunction

        function void report();
            $display("======== COSTAS COVERAGE ========");
            $display(" cg_ctrl       : %6.2f %%", cg_ctrl.get_inst_coverage());
            $display(" cg_valid_pre  : %6.2f %%", cg_valid_pre.get_inst_coverage());
            $display(" cg_sym        : %6.2f %%", cg_sym.get_inst_coverage());
            $display(" cg_qam_points : %6.2f %%", cg_qam_points.get_inst_coverage());
            $display(" cg_err        : %6.2f %%", cg_err.get_inst_coverage());
            $display(" cg_pi         : %6.2f %%", cg_pi.get_inst_coverage());
            $display(" cg_lock       : %6.2f %%", cg_lock.get_inst_coverage());
            $display(" cg_quad       : %6.2f %%", cg_quad.get_inst_coverage());
            $display("=================================");
        endfunction

    endclass

endpackage
