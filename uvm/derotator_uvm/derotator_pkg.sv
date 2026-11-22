// ============================================================================
// File Name   : derotator_pkg.sv
// Module Name : derotator_pkg
// Author      : Arwa Kantoush
// Description : Verification package containing transaction definitions,
//               NCO phase tracking helpers, and functional coverage models for
//               the Derotator (frequency/phase compensation) subsystem.
// ============================================================================
package derotator_pkg;

    class derotator_transaction;

        // ------------------------------------------------------------------
        // Constants
        // ------------------------------------------------------------------
        parameter int FULL_POS = 32767;     // Q1.15 max
        parameter int FULL_NEG = -32768;    // Q1.15 min (-1.0)
        parameter int IDX_MAX  = 4095;      // last ROM address
        parameter int SMALL    = 4096;      // 0.125 full scale
        parameter int MID      = 16384;     // 0.5   full scale
        parameter int C_SMALL  = 1048576;   // 2^20, coarse/adj magnitude split

        // ------------------------------------------------------------------
        // Inputs (set by the testbench / monitor)
        // ------------------------------------------------------------------
        logic                s_valid;
        logic signed [15:0]  i_sym, q_sym;
        logic                coarse_valid;
        logic signed [23:0]  coarse_word;
        logic                freq_adj_valid;
        logic signed [31:0]  freq_adj;
        logic                phase_adj_valid;
        logic        [31:0]  phase_adj;
        logic                force_en;          // force_freq_en_i (DFT)

        // ------------------------------------------------------------------
        // Observed
        // ------------------------------------------------------------------
        logic        [31:0]  phase;             // NCO phase this symbol uses (pre-increment)
        logic        [1:0]   quad;              // phase[31:30]
        logic        [11:0]  lut_idx;           // phase[29:18]
        logic signed [31:0]  freq_word;         // freq_word_o
        logic                m_valid;
        logic signed [15:0]  m_i, m_q;

        // Quadrant of the symbol that is now at the output
        logic        [1:0]   out_quad;
        logic        [1:0]   quad_pipe [$];

        // Splits the NCO phase exactly like NCO_accumulator (Phase_Bits = 12)
        function void set_phase(logic [31:0] p);
            phase   = p;
            quad    = p[31:30];
            lut_idx = p[29:18];
        endfunction

        // ==================================================================
        // Requirement_1: input valid strobe (no ready): gaps, bursts
        // ==================================================================
        covergroup cg_in_valid;
            cp_valid: coverpoint s_valid {
                bins v_1          = {1};
                bins v_0          = {0};
                bins gap_to_valid = (0 => 1);
                bins valid_to_gap = (1 => 0);
                ignore_bins back2back = (1 [* 4]);   // N/A here: STR gives 1 valid per 4 clk. Re-enable with a burst sequence
                bins long_gap     = (0 [* 3]);
            }
        endgroup: cg_in_valid

        // ==================================================================
        // Requirement_2: NCO phase seen by each symbol: quadrant, ROM index
        //                region (exact first/last address included) and
        //                quadrant transitions (phase wrap)
        // ==================================================================
        covergroup cg_nco;
            cp_quad: coverpoint quad iff (s_valid) {
                bins q0 = {2'd0};
                bins q1 = {2'd1};
                bins q2 = {2'd2};
                bins q3 = {2'd3};
            }
            cp_idx: coverpoint lut_idx iff (s_valid) {
                bins idx_0       = {0};                       // exact first address
                bins idx_first   = {[1    : 15]};
                bins idx_low     = {[16   : 1023]};
                bins idx_midlow  = {[1024 : 2047]};
                bins idx_midhigh = {[2048 : 3071]};
                bins idx_high    = {[3072 : IDX_MAX-16]};
                bins idx_last    = {[IDX_MAX-15 : IDX_MAX-1]};
                bins idx_4095    = {IDX_MAX};                 // exact last address
            }
            cx_quad_idx: cross cp_quad, cp_idx;
            // Consecutive valid symbols only (iff gates the sampling)
            cp_quad_tr: coverpoint quad iff (s_valid) {
                bins wrap_up  = (2'd3 => 2'd0);         // positive frequency, 2^32 wrap
                bins wrap_dn  = (2'd0 => 2'd3);         // negative frequency, underflow
                bins fwd_step = (2'd0 => 2'd1), (2'd1 => 2'd2), (2'd2 => 2'd3);
                bins bck_step = (2'd1 => 2'd0), (2'd2 => 2'd1), (2'd3 => 2'd2);
                ignore_bins jump_2 = (2'd0 => 2'd2), (2'd2 => 2'd0), (2'd1 => 2'd3), (2'd3 => 2'd1);
            }
        endgroup: cg_nco

        // ==================================================================
        // Requirement_3: input symbol: sign quadrant, level, full-scale corners
        //                and the saturating negation of quadrant_rotator
        // ==================================================================
        covergroup cg_input_sym;
            cp_sign: coverpoint {i_sym[15], q_sym[15]} iff (s_valid) {
                bins Q1 = {2'b00};
                bins Q2 = {2'b10};
                bins Q3 = {2'b11};
                bins Q4 = {2'b01};
            }
            cp_i_lvl: coverpoint i_sym iff (s_valid) {
                bins min_neg   = {FULL_NEG};
                bins neg_large = {[-FULL_POS : -(MID+1)]};
                bins neg_mid   = {[-MID      : -(SMALL+1)]};
                bins neg_small = {[-SMALL    : -1]};
                ignore_bins zero = {0};
                bins pos_small = {[1          : SMALL]};
                bins pos_mid   = {[SMALL+1    : MID]};
                bins pos_large = {[MID+1      : FULL_POS-1]};
                bins max_pos   = {FULL_POS};
            }
            cp_q_lvl: coverpoint q_sym iff (s_valid) {
                bins min_neg   = {FULL_NEG};
                bins neg_large = {[-FULL_POS : -(MID+1)]};
                bins neg_mid   = {[-MID      : -(SMALL+1)]};
                bins neg_small = {[-SMALL    : -1]};
                ignore_bins zero = {0};
                bins pos_small = {[1          : SMALL]};
                bins pos_mid   = {[SMALL+1    : MID]};
                bins pos_large = {[MID+1      : FULL_POS-1]};
                bins max_pos   = {FULL_POS};
            }
            cp_quad: coverpoint quad iff (s_valid) {
                bins q0 = {2'd0};
                bins q1 = {2'd1};
                bins q2 = {2'd2};
                bins q3 = {2'd3};
            }
            // sign of the input symbol in every NCO quadrant
            cx_sign_quad: cross cp_sign, cp_quad;

            // quadrant_rotator neg(): -(-1.0) must give +0.99997
            cp_min: coverpoint {(i_sym == FULL_NEG), (q_sym == FULL_NEG)} iff (s_valid) {
                bins i_min = {2'b10};
                bins q_min = {2'b01};
            }
            cx_neg_sat: cross cp_quad, cp_min {
                // q0 never negates; q1 negates only xi; q3 negates only xq; q2 negates both
                ignore_bins q0_no_neg = binsof(cp_quad.q0);
                ignore_bins q1_qmin   = binsof(cp_quad.q1) && binsof(cp_min.q_min);
                ignore_bins q3_imin   = binsof(cp_quad.q3) && binsof(cp_min.i_min);
            }

            // Full-scale corner pairs, in every quadrant
            cp_corner: coverpoint {(i_sym == FULL_NEG), (q_sym == FULL_NEG),
                                   (i_sym == FULL_POS), (q_sym == FULL_POS)} iff (s_valid) {
                bins imin_qmax = {4'b1001};
                bins imax_qmin = {4'b0110};
                bins both_min  = {4'b1100};
                bins both_max  = {4'b0011};
            }
            cx_corner_quad: cross cp_corner, cp_quad;
        endgroup: cg_input_sym

        // ==================================================================
        // Requirement_4: frequency word path: coarse load, PI correction,
        //                same-cycle load, DFT override
        // ==================================================================
        covergroup cg_freq;
            cp_coarse_v: coverpoint coarse_valid {
                bins pulse = {1};
                bins idle  = {0};
            }
            cp_adj_v: coverpoint freq_adj_valid {
                bins pulse = {1};
                bins idle  = {0};
            }
            cp_coarse: coverpoint coarse_word iff (coarse_valid) {
                bins neg_large = {[$           : -(C_SMALL+1)]};
                bins neg_small = {[-C_SMALL    : -1]};
                ignore_bins zero = {0};
                bins pos_small = {[1           : C_SMALL]};
                bins pos_large = {[C_SMALL+1   : $]};
            }
            cp_adj: coverpoint freq_adj iff (freq_adj_valid) {
                bins neg_large = {[$           : -(C_SMALL+1)]};
                bins neg_small = {[-C_SMALL    : -1]};
                ignore_bins zero = {0};
                bins pos_small = {[1           : C_SMALL]};
                bins pos_large = {[C_SMALL+1   : $]};
            }
            // coarse and correction arriving in the same cycle (bypass path)
            cx_coarse_adj: cross cp_coarse_v, cp_adj_v;
            // frequency word really used by a valid symbol
            cp_fw: coverpoint freq_word iff (s_valid) {
                ignore_bins zero = {0};         // N/A: symbols only start after the coarse word
                bins neg  = {[$ : -1]};
                bins pos  = {[1 : $]};
            }
            cp_force: coverpoint force_en {
                bins off = {0};
                bins on  = {1};
                bins off_to_on = (0 => 1);
                bins on_to_off = (1 => 0);
            }
        endgroup: cg_freq

        // ==================================================================
        // Requirement_5: initial phase correction k*pi/2 (rising edge)
        // ==================================================================
        covergroup cg_phase_adj;
            cp_adj_v: coverpoint phase_adj_valid {
                bins rise = (0 => 1);
                bins held = (1 [* 2]);          // held high: correction added once only
                bins fall = (1 => 0);
            }
            cp_k: coverpoint phase_adj[31:30] iff (phase_adj_valid) {
                bins k0 = {2'b00};
                bins k1 = {2'b01};
                bins k2 = {2'b10};
                bins k3 = {2'b11};
            }
            cp_with_sym: coverpoint s_valid iff (phase_adj_valid) {
                bins with_symbol    = {1};      // same cycle as a valid symbol (spec case)
                ignore_bins without_symbol = {0};
            }
            cx_k_sym: cross cp_k, cp_with_sym;
        endgroup: cg_phase_adj

        // ==================================================================
        // Requirement_6: derotated output: valid pattern, sign, saturation,
        //                and saturation per quadrant of the source symbol
        // ==================================================================
        covergroup cg_output;
            cp_mv: coverpoint m_valid {
                bins v_1          = {1};
                bins v_0          = {0};
                bins gap_to_valid = (0 => 1);
                bins valid_to_gap = (1 => 0);
                ignore_bins back2back = (1 [* 4]);   // N/A here, see cg_in_valid
            }
            cp_osign: coverpoint {m_i[15], m_q[15]} iff (m_valid) {
                bins Q1 = {2'b00};
                bins Q2 = {2'b10};
                bins Q3 = {2'b11};
                bins Q4 = {2'b01};
            }
            cp_oi: coverpoint m_i iff (m_valid) {
                bins sat_min = {FULL_NEG};
                bins neg     = {[-FULL_POS : -1]};
                ignore_bins zero = {0};
                bins pos     = {[1 : FULL_POS-1]};
                bins sat_max = {FULL_POS};
            }
            cp_oq: coverpoint m_q iff (m_valid) {
                bins sat_min = {FULL_NEG};
                bins neg     = {[-FULL_POS : -1]};
                ignore_bins zero = {0};
                bins pos     = {[1 : FULL_POS-1]};
                bins sat_max = {FULL_POS};
            }
            // Explicit "normal" bin (NOT default: default bins are dropped from crosses)
            cp_sat_i: coverpoint m_i iff (m_valid) {
                bins sat_min = {FULL_NEG};
                bins normal  = {[FULL_NEG+1 : FULL_POS-1]};
                bins sat_max = {FULL_POS};
            }
            cp_sat_q: coverpoint m_q iff (m_valid) {
                bins sat_min = {FULL_NEG};
                bins normal  = {[FULL_NEG+1 : FULL_POS-1]};
                bins sat_max = {FULL_POS};
            }
            cp_out_quad: coverpoint out_quad iff (m_valid) {
                bins q0 = {2'd0};
                bins q1 = {2'd1};
                bins q2 = {2'd2};
                bins q3 = {2'd3};
            }
            cx_sat_i_quad: cross cp_sat_i, cp_out_quad;
            cx_sat_q_quad: cross cp_sat_q, cp_out_quad;
        endgroup: cg_output

        // ------------------------------------------------------------------
        function new();
            cg_in_valid  = new();
            cg_nco       = new();
            cg_input_sym = new();
            cg_freq      = new();
            cg_phase_adj = new();
            cg_output    = new();
            out_quad     = '0;
        endfunction

        // Clear the quadrant tracking queue (call on reset)
        function void reset_tracking();
            quad_pipe.delete();
            out_quad = '0;
        endfunction

        // Call before the clock edge, with the stimulus and the NCO state
        function void sample_in();
            if (s_valid) quad_pipe.push_back(quad);   // quad = pre-increment NCO quadrant
            cg_in_valid.sample();
            cg_nco.sample();
            cg_input_sym.sample();
            cg_freq.sample();
            cg_phase_adj.sample();
        endfunction

        // Call after the clock edge, once the DUT outputs are updated
        function void sample_out();
            if (m_valid && quad_pipe.size() > 0) out_quad = quad_pipe.pop_front();
            cg_output.sample();
        endfunction

        function void report();
            $display("======== DEROTATOR COVERAGE ========");
            $display(" cg_in_valid  : %6.2f %%", cg_in_valid.get_inst_coverage());
            $display(" cg_nco       : %6.2f %%", cg_nco.get_inst_coverage());
            $display(" cg_input_sym : %6.2f %%", cg_input_sym.get_inst_coverage());
            $display(" cg_freq      : %6.2f %%", cg_freq.get_inst_coverage());
            $display(" cg_phase_adj : %6.2f %%", cg_phase_adj.get_inst_coverage());
            $display(" cg_output    : %6.2f %%", cg_output.get_inst_coverage());
            $display("====================================");
        endfunction

    endclass

endpackage
