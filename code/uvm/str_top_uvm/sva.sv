module sva (
    input logic                clk_i,
    input logic                rst_ni,

    // ---- str_top ports ----
    input logic                s_axis_valid_i,
    input logic                flush_active_i,
    input logic [11:0]         s_axis_i_sample_i,
    input logic [11:0]         s_axis_q_sample_i,
    input logic                force_w_en_i,
    input logic [15:0]         force_w_i,
    input logic                m_axis_valid_o,
    input logic signed [15:0]  m_axis_i_sym_o,
    input logic signed [15:0]  m_axis_q_sym_o,
    input logic                lock_o,
    input logic                ted_err_valid_o,
    input logic signed [31:0]  ted_err_o,
    input logic [9:0]          mu_o,
    input logic [15:0]         w_o,

    // ---- str_top internal nets ----
    input logic                ce_str,
    input logic                mid_strobe,        // modulo-1 controller outputs
    input logic                curr_strobe,
    input logic                mid_strobe_d,      // after the 4-stage alignment pipe
    input logic                curr_strobe_d,
    input logic signed [15:0]  i_y, q_y,          // interpolator outputs
    input logic signed [15:0]  i_mid, q_mid,
    input logic signed [15:0]  i_cur, q_cur,
    input logic signed [15:0]  i_prev, q_prev,
    input logic signed [23:0]  pi_val,            // PI filter output (sQ-1.24)
    input logic signed [15:0]  w_val              // NCO step, uQ0.24 [23:8]
);

    default clocking cb @(posedge clk_i); endclocking
    default disable iff (!rst_ni);

    // -------------------------------------------------------------------------
    // Helper state (counts only on ce_str cycles, because the STR freezes
    // when ce_str = 0)
    // -------------------------------------------------------------------------
    logic [7:0] cur_gap, mid_gap, evt_gap;   // ce-cycles since the previous strobe
    logic       seen_cur, seen_mid, seen_evt;
    logic       last_was_mid;                // 0 after reset: first strobe must be "mid"

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            cur_gap      <= '0;
            mid_gap      <= '0;
            evt_gap      <= '0;
            seen_cur     <= 1'b0;
            seen_mid     <= 1'b0;
            seen_evt     <= 1'b0;
            last_was_mid <= 1'b0;
        end else if (ce_str) begin
            if (curr_strobe) begin
                cur_gap  <= 8'd1;
                seen_cur <= 1'b1;
            end else if (cur_gap != 8'hFF) begin
                cur_gap  <= cur_gap + 8'd1;
            end

            if (mid_strobe) begin
                mid_gap  <= 8'd1;
                seen_mid <= 1'b1;
            end else if (mid_gap != 8'hFF) begin
                mid_gap  <= mid_gap + 8'd1;
            end

            if (curr_strobe || mid_strobe) begin
                evt_gap      <= 8'd1;
                seen_evt     <= 1'b1;
                last_was_mid <= mid_strobe;
            end else if (evt_gap != 8'hFF) begin
                evt_gap      <= evt_gap + 8'd1;
            end
        end
    end

    // Bit-exact model of gardner_ted_estimator (products, sum, >>>9, sign-extend)
    function automatic logic signed [31:0] ted_model (
        input logic signed [15:0] im, qm, ic, qc, ip, qp
    );
        logic signed [16:0] di, dq;
        logic signed [32:0] pi_prod, pq_prod;
        logic signed [33:0] sum;
        logic signed [24:0] q21;
        di      = ic - ip;
        dq      = qc - qp;
        pi_prod = im * di;
        pq_prod = qm * dq;
        sum     = pi_prod + pq_prod;
        q21     = sum >>> 9;
        return {{7{q21[24]}}, q21};
    endfunction

    // =========================================================================
    // 1. Reset
    // =========================================================================
    // Synchronous reset clears every registered output on the next clock.
    a_reset_outputs: assert property (
        @(posedge clk_i) disable iff (1'b0)
        !rst_ni |=> (m_axis_valid_o == 1'b0 && ted_err_valid_o == 1'b0 &&
                     ted_err_o == 32'sd0 && mu_o == 10'd0 &&
                     m_axis_i_sym_o == 16'sd0 && m_axis_q_sym_o == 16'sd0)
    ) else $error("SVA: outputs not cleared by synchronous reset");

    // =========================================================================
    // 2. Inputs / outputs are never X or Z once out of reset
    // =========================================================================
    a_inputs_ctrl_known: assert property (
        !$isunknown({s_axis_valid_i, flush_active_i, force_w_en_i})
    ) else $error("SVA: X/Z on valid/flush/force_w_en inputs");

    a_inputs_data_known: assert property (
        ce_str |-> !$isunknown({s_axis_i_sample_i, s_axis_q_sample_i})
    ) else $error("SVA: X/Z on sample inputs while ce_str=1");

    a_outputs_known: assert property (
        !$isunknown({m_axis_valid_o, m_axis_i_sym_o, m_axis_q_sym_o,
                     ted_err_valid_o, ted_err_o, mu_o, w_o})
    ) else $error("SVA: X/Z on a DUT output");

    a_lock_known: assert property (
        !$isunknown(lock_o)
    ) else $error("SVA: X/Z on lock_o");

    // =========================================================================
    // 3. Clock enable: definition and freeze behaviour
    // =========================================================================
    a_ce_definition: assert property (
        ce_str === (s_axis_valid_i | flush_active_i)
    ) else $error("SVA: ce_str != s_axis_valid_i | flush_active_i");

    // With ce_str = 0 the interpolators, modulo controller and TED hold state.
    a_freeze_outputs: assert property (
        !ce_str |=> $stable({mu_o, ted_err_o, ted_err_valid_o,
                             m_axis_i_sym_o, m_axis_q_sym_o,
                             mid_strobe, curr_strobe})
    ) else $error("SVA: state changed while ce_str=0");

    // The strobe pipeline last stage is cleared when ce_str = 0, so the output
    // valid can never stay high (or rise) in a cycle that follows ce_str = 0.
    a_valid_drops_without_ce: assert property (
        !ce_str |=> !m_axis_valid_o
    ) else $error("SVA: m_axis_valid_o high after a ce_str=0 cycle");

    // =========================================================================
    // 4. Strobe protocol
    // =========================================================================
    a_strobe_exclusive: assert property (
        !(mid_strobe && curr_strobe)
    ) else $error("SVA: mid and current strobe in the same cycle");

    a_strobe_d_exclusive: assert property (
        !(mid_strobe_d && curr_strobe_d)
    ) else $error("SVA: delayed mid and current strobe in the same cycle");

    // m_axis_valid_o is the delayed current strobe
    a_valid_is_curr_strobe_d: assert property (
        m_axis_valid_o === curr_strobe_d
    ) else $error("SVA: m_axis_valid_o != curr_strobe_d");

    // Alignment pipe: a strobe appears 4 ce-cycles later (4 consecutive ce_str)
    a_curr_strobe_delay: assert property (
        (ce_str && curr_strobe) ##1 ce_str[*3] |=> curr_strobe_d
    ) else $error("SVA: curr_strobe not delayed by 4 ce cycles");

    a_mid_strobe_delay: assert property (
        (ce_str && mid_strobe) ##1 ce_str[*3] |=> mid_strobe_d
    ) else $error("SVA: mid_strobe not delayed by 4 ce cycles");

    // Strobes alternate mid, current, mid, current ... (first one after reset is mid,
    // because the NCO phase starts at 0.75)
    a_alt_curr_after_mid: assert property (
        (ce_str && curr_strobe) |-> last_was_mid
    ) else $error("SVA: current strobe not preceded by a mid strobe");

    a_alt_mid_after_curr: assert property (
        (ce_str && mid_strobe) |-> !last_was_mid
    ) else $error("SVA: mid strobe not preceded by a current strobe");

    // Spacing in ce-cycles. The NCO step W = 0.25 + pi with |pi| <= 0.035, so
    // W is in [0.215, 0.285]:  symbol period between 3 and 5 samples,
    // half-symbol (mid<->current) spacing at most 3 samples.
    a_cur_spacing: assert property (
        (ce_str && curr_strobe && seen_cur) |-> (cur_gap >= 8'd3 && cur_gap <= 8'd5)
    ) else $error("SVA: current strobe spacing outside 3..5 samples");

    a_mid_spacing: assert property (
        (ce_str && mid_strobe && seen_mid) |-> (mid_gap >= 8'd3 && mid_gap <= 8'd5)
    ) else $error("SVA: mid strobe spacing outside 3..5 samples");

    a_event_spacing: assert property (
        (ce_str && (curr_strobe || mid_strobe) && seen_evt) |-> (evt_gap <= 8'd3)
    ) else $error("SVA: more than 3 samples between consecutive strobes");

    // mu is only reloaded together with a strobe
    a_mu_changes_on_strobe: assert property (
        $changed(mu_o) |-> (curr_strobe || mid_strobe)
    ) else $error("SVA: mu_o changed without a strobe");

    // =========================================================================
    // 5. Loop filter / NCO ranges
    // =========================================================================
    // PI output is clamped to +-0.035 in sQ-1.24: [-587203, 587202]
    a_pi_range: assert property (
        (pi_val >= -587203) && (pi_val <= 587202)
    ) else $error("SVA: pi_val outside the +-0.035 clamp");

    // W = 0.25 + pi  ->  upper 16 bits of uQ0.24 in [14090, 18677]
    a_w_range: assert property (
        (w_val >= 14090) && (w_val <= 18677)
    ) else $error("SVA: NCO step W outside [0.215, 0.285]");

    // DFT force mux on w_o
    a_w_force_mux: assert property (
        w_o === (force_w_en_i ? force_w_i : w_val[15:0])
    ) else $error("SVA: w_o does not follow the force_w mux");

    // =========================================================================
    // 6. Gardner TED data path
    // =========================================================================
    // Symbol registers capture the interpolator output on their strobes ...
    a_cur_capture: assert property (
        (ce_str && curr_strobe_d) |=> (i_cur  == $past(i_y)   && q_cur  == $past(q_y) &&
                                       i_prev == $past(i_cur) && q_prev == $past(q_cur))
    ) else $error("SVA: i_cur/i_prev capture wrong");

    a_mid_capture: assert property (
        (ce_str && mid_strobe_d) |=> (i_mid == $past(i_y) && q_mid == $past(q_y))
    ) else $error("SVA: i_mid/q_mid capture wrong");

    // ... and hold otherwise
    a_cur_hold: assert property (
        !(ce_str && curr_strobe_d) |=> $stable({i_cur, q_cur, i_prev, q_prev})
    ) else $error("SVA: cur/prev registers changed without a strobe");

    a_mid_hold: assert property (
        !(ce_str && mid_strobe_d) |=> $stable({i_mid, q_mid})
    ) else $error("SVA: mid registers changed without a strobe");

    // TED latency: valid two ce-cycles after the current strobe
    a_ted_valid_latency: assert property (
        (ce_str && curr_strobe_d) ##1 ce_str |=> ted_err_valid_o
    ) else $error("SVA: ted_err_valid_o not raised 2 ce cycles after curr_strobe_d");

    // TED value: e = mid_I*(cur_I-prev_I) + mid_Q*(cur_Q-prev_Q), >>>9, sign-extended
    property p_ted_value;
        logic signed [31:0] exp_err;
        (ce_str && curr_strobe_d,
            exp_err = ted_model(i_mid, q_mid, i_y, q_y, i_cur, q_cur))
        ##1 ce_str |=> (ted_err_o == exp_err);
    endproperty

    a_ted_value: assert property (p_ted_value)
        else $error("SVA: ted_err_o != Gardner model");

    // TED output is a sign-extended 25-bit value
    a_ted_sign_ext: assert property (
        ted_err_o[31:25] == {7{ted_err_o[24]}}
    ) else $error("SVA: ted_err_o is not a sign-extended sQ3.21 value");

    // =========================================================================
    // Cover points (show in the coverage report which scenarios really happened)
    // =========================================================================
    c_mid_strobe : cover property (ce_str && mid_strobe);
    c_curr_strobe: cover property (ce_str && curr_strobe);
    c_out_valid  : cover property (m_axis_valid_o);
    c_ted_valid  : cover property (ted_err_valid_o);
    c_lock_rise  : cover property ($rose(lock_o));
    c_lock_fall  : cover property ($fell(lock_o));
    c_flush_only : cover property (flush_active_i && !s_axis_valid_i);
    c_input_gap  : cover property (s_axis_valid_i ##1 !ce_str);
    c_cur_gap3   : cover property (ce_str && curr_strobe && seen_cur && cur_gap == 8'd3);
    c_cur_gap4   : cover property (ce_str && curr_strobe && seen_cur && cur_gap == 8'd4);
    c_cur_gap5   : cover property (ce_str && curr_strobe && seen_cur && cur_gap == 8'd5);
    c_pi_pos     : cover property (pi_val > 0);
    c_pi_neg     : cover property (pi_val < 0);
    c_pi_sat_hi  : cover property (pi_val == 587202);
    c_pi_sat_lo  : cover property (pi_val == -587203);
    c_force_w    : cover property (force_w_en_i);

endmodule


// -----------------------------------------------------------------------------
// Bind: instantiates sva inside every str_top (here: top.dut.u_sva)
// -----------------------------------------------------------------------------
bind str_top sva u_sva (
    .clk_i             (clk_i),
    .rst_ni            (rst_ni),
    .s_axis_valid_i    (s_axis_valid_i),
    .flush_active_i    (flush_active_i),
    .s_axis_i_sample_i (s_axis_i_sample_i),
    .s_axis_q_sample_i (s_axis_q_sample_i),
    .force_w_en_i      (force_w_en_i),
    .force_w_i         (force_w_i),
    .m_axis_valid_o    (m_axis_valid_o),
    .m_axis_i_sym_o    (m_axis_i_sym_o),
    .m_axis_q_sym_o    (m_axis_q_sym_o),
    .lock_o            (lock_o),
    .ted_err_valid_o   (ted_err_valid_o),
    .ted_err_o         (ted_err_o),
    .mu_o              (mu_o),
    .w_o               (w_o),
    .ce_str            (ce_str),
    .mid_strobe        (mid_strobe),
    .curr_strobe       (curr_strobe),
    .mid_strobe_d      (mid_strobe_d),
    .curr_strobe_d     (curr_strobe_d),
    .i_y               (i_y),
    .q_y               (q_y),
    .i_mid             (i_mid),
    .q_mid             (q_mid),
    .i_cur             (i_cur),
    .q_cur             (q_cur),
    .i_prev            (i_prev),
    .q_prev            (q_prev),
    .pi_val            (pi_val),
    .w_val             (w_val)
);
