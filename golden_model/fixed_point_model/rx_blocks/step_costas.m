function [out, st] = step_costas(in, st, T)
    % STEP_COSTAS  Cycle-Accurate Fixed-Point Decision-Directed Costas Loop (costas.md).
    %
    % Mathematical Model & Hardware Stages:
    %   1. Slicer:
    %      Combinational hard-decision slicer for QPSK (+-d) or 16-QAM (+-d, +-3d).
    %      Forces QPSK slicing during preamble to prevent false locks.
    %   2. Decision-Directed Phase Error Detector:
    %      e = Im{y * conj(a)} = y_Q * a_I - y_I * a_Q
    %   3. PI Loop Filter:
    %      acc <- acc + Ki * e (anti-windup saturation)
    %      v_pi = Kp * e + acc (saturating at +-max_v_pi)
    %   4. Quadrant Ambiguity Resolution:
    %      Two 5-bit signed up/down counters (-16..+15) accumulate slicer signs in Phase C.
    %      Resolves 90-degree ambiguity and pulses phase_adj (k * pi/2) to NCO.
    %   5. Dual Lock Detectors:
    %      - Internal: enables quadrant sign counters during lock
    %      - Public: stays low until initial phase ambiguity is resolved.

    R   = T.rd;
    C   = T.costas;
    Lc  = T.lat.costas;
    MODE_HOLD = T.enc.mode.HOLD;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & REGISTERS INITIALIZATION (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.acc       = T.fi(0, 'freq_w');
        st.pw_val    = false(1, 3);
        st.pw_pi     = T.fi(zeros(1, 3), 'freq_w');
        st.sat_pos   = false;
        st.sat_neg   = false;

        % phase_error.sv 3-stage pipeline + 1-stage slicer sign register (costas_top.sv)
        st.pe_vm       = false;
        st.pe_vd       = false;
        st.pe_m_qa     = int64(0);
        st.pe_m_ia     = int64(0);
        st.pe_diff     = int64(0);
        st.pe_e_int    = int64(0);
        st.sgn_i_pos_q = false;
        st.sgn_q_pos_q = false;

        % kp/ki 3-stage pipeline matching costas_top.sv lines 133-152
        st.kp_pipe   = repmat(int64(220364), 1, 3);
        st.ki_pipe   = repmat(int64(7347),   1, 3);

        st.li        = init_costas_hw_ld(uint32(5734), 12, 0);
        st.lp        = init_costas_hw_ld(uint32(8192), 12, 15);
        st.cnt_i     = T.fi(0, 'sgn_cnt', 'sat');
        st.cnt_q     = T.fi(0, 'sgn_cnt', 'sat');
        st.reported  = false;
        st.corr_sent = false;
        st.unres     = false;
        st.quad_q    = NaN;
        st.quad_k    = NaN;
        st.pa_val    = false;
        st.pa_word   = T.fi(0, 'phase');
        st.err_val   = false;
        st.err_reg   = T.fi(0, 'cos_e');
        st.a_ref     = 0.0;
        st.ai        = T.fi(0, 'cos_a');
        st.aq        = T.fi(0, 'cos_a');
        st.sat_cnt   = 0;
        st.sym_cnt   = 0;

        out = costas_drive_outputs(st, T);
        return;
    end

    st_old   = st;
    mode     = double(in.mode_i);
    use_qpsk = (double(in.mod_type_i) == T.enc.mod.QPSK) || logical(in.slicer_qpsk_i);
    if use_qpsk
        row = 1;
    else
        row = min(double(in.mod_type_i), 1) + 1;
    end

    % Combinational gains/thresholds & kp/ki 3-stage shift register (costas_top.sv)
    if mode == T.enc.mode.ACQ || use_qpsk
        kp_cur = int64(220364);
        ki_cur = int64(7347);
    else
        kp_cur = int64(396656);
        ki_cur = int64(13224);
    end
    st.kp_pipe = [kp_cur, st_old.kp_pipe(1:2)];
    st.ki_pipe = [ki_cur, st_old.ki_pipe(1:2)];

    % 1-stage slicer sign register (updates only on s_axis_valid_i; not cleared on MODE_HOLD)
    if in.s_axis_valid_i
        st.sym_cnt = st_old.sym_cnt + 1;
        yi = R(T.fi(in.s_axis_i_sym_i, 'rot_out'));
        yq = R(T.fi(in.s_axis_q_sym_i, 'rot_out'));
        [ai, aq] = fxp_slicer(yi, yq, (mode == MODE_HOLD) || use_qpsk, C);
        st.ai    = ai;
        st.aq    = aq;
        st.a_ref = (double(ai) + 1j * double(aq)) / T.in_scale;
        st.sgn_i_pos_q = (int64(storedInteger(yi)) >= 0);
        st.sgn_q_pos_q = (int64(storedInteger(yq)) >= 0);
    end

    if mode == MODE_HOLD
        st.pe_vm     = false;
        st.pe_vd     = false;
        st.pe_e_int  = int64(0);
        st.err_val   = false;
        st.err_reg(:)= T.fi(0, 'cos_e');
        st.cnt_i(:)  = 0;
        st.cnt_q(:)  = 0;
        st.reported  = false;
        st.corr_sent = false;
        st.unres     = false;
        st.quad_q    = NaN;
        st.quad_k    = NaN;
        st.sat_pos   = false;
        st.sat_neg   = false;
        st.acc(:)    = T.fi(0, 'freq_w');
        st.li        = init_costas_hw_ld(uint32(5734), 12, 0);
        st.lp        = init_costas_hw_ld(uint32(8192), 12, 15);
        st.pa_val    = false;
        st.pa_word(:)= T.fi(0, 'phase');
        st.pw_val(:) = false;
        st.pw_pi(:)  = T.fi(0, 'freq_w');
        out = costas_drive_outputs(st, T);
        return;
    end

    % ---------------------------------------------------------------------
    % 2. PHASE ERROR DETECTOR 3-STAGE PIPELINE (phase_error.sv)
    % ---------------------------------------------------------------------
    if in.s_axis_valid_i
        yi_int = int64(storedInteger(yi));
        yq_int = int64(storedInteger(yq));
        ai_int = int64(storedInteger(ai));
        aq_int = int64(storedInteger(aq));
        st.pe_m_qa = yq_int * ai_int;
        st.pe_m_ia = yi_int * aq_int;
    end
    if st_old.pe_vm
        st.pe_diff = st_old.pe_m_qa - st_old.pe_m_ia;
    end
    st.pe_vm   = logical(in.s_axis_valid_i);
    st.pe_vd   = st_old.pe_vm;
    st.err_val = st_old.pe_vd;
    if st_old.pe_vd
        shifted = bitsra(st_old.pe_diff, 15);
        if shifted > 32767
            e_int = int64(32767);
        elseif shifted < -32768
            e_int = int64(-32768);
        else
            e_int = shifted;
        end
        st.pe_e_int   = e_int;
        st.err_reg(:) = T.fi(double(e_int) * (2^-15), 'cos_e');
    end

    % Registered outputs of phase_error.sv available on this clock edge:
    e_valid_r = st_old.err_val;
    e_reg_int = st_old.pe_e_int;

    % ---------------------------------------------------------------------
    % 3. PI LOOP FILTER (3-stage pipeline fed by phase_error valid_o)
    % ---------------------------------------------------------------------
    if e_valid_r
        sat_pos_prev = isfield(st_old, 'sat_pos') && logical(st_old.sat_pos);
        sat_neg_prev = isfield(st_old, 'sat_neg') && logical(st_old.sat_neg);
        acc_cur_int  = int64(storedInteger(st_old.acc));
        kp_use       = st_old.kp_pipe(3);
        ki_use       = st_old.ki_pipe(3);

        [v_pi, acc_new, sat_pos, sat_neg] = fxp_costas_pi(...
            e_reg_int, acc_cur_int, kp_use, ki_use, sat_pos_prev, sat_neg_prev, T);

        st.acc(:)  = acc_new;
        st.sat_pos = sat_pos;
        st.sat_neg = sat_neg;
        if sat_pos || sat_neg
            st.sat_cnt = st_old.sat_cnt + 1;
        end
        new_pw_val = true;
        new_pw_pi  = v_pi;
    else
        new_pw_val = false;
        new_pw_pi  = T.fi(0, 'freq_w');
    end
    st.pw_val    = [new_pw_val,   st_old.pw_val(1:end-1)];
    st.pw_pi(:)  = [R(new_pw_pi), R(st_old.pw_pi(1:end-1))];

    % ---------------------------------------------------------------------
    % 4. INTERNAL LOCK DETECTOR (costas_top.sv lines 203-219: Lock_Int_* constants)
    % ---------------------------------------------------------------------
    li_val = e_valid_r && ~st_old.reported;
    [st.li, lock_int_comb] = step_costas_hw_ld(st_old.li, li_val, e_reg_int, uint32(3277), uint32(4915));

    % ---------------------------------------------------------------------
    % 5. QUADRANT AMBIGUITY CHECK (quad_check.sv + costas_top.sv lines 221-236)
    % ---------------------------------------------------------------------
    ci = R(st_old.cnt_i);
    cq = R(st_old.cnt_q);
    st.pa_val = false;

    if ~st_old.reported
        if ~lock_int_comb
            ci_next = 0;
            cq_next = 0;
        elseif e_valid_r
            if st_old.sgn_i_pos_q, si = 1; else, si = -1; end
            if st_old.sgn_q_pos_q, sq = 1; else, sq = -1; end
            ci_next = min(max(ci + si, C.cnt_full_neg), C.cnt_full_pos);
            cq_next = min(max(cq + sq, C.cnt_full_neg), C.cnt_full_pos);
        else
            ci_next = ci;
            cq_next = cq;
        end

        full_any = (ci_next == C.cnt_full_pos) || (ci_next == C.cnt_full_neg) || ...
                   (cq_next == C.cnt_full_pos) || (cq_next == C.cnt_full_neg);
        evt      = full_any || logical(in.preamble_end_i);
        unknown  = (ci_next == 0) || (cq_next == 0);

        if ~lock_int_comb
            ci = 0;
            cq = 0;
        elseif e_valid_r
            ci = ci_next;
            cq = cq_next;
        end

        if evt
            st.reported = true;
            if unknown
                st.unres     = true;
                st.corr_sent = false;
                st.quad_q    = NaN;
                st.quad_k    = NaN;
            else
                if ci_next > 0 && cq_next > 0
                    q = 1;
                elseif ci_next < 0 && cq_next > 0
                    q = 2;
                elseif ci_next < 0 && cq_next < 0
                    q = 3;
                else
                    q = 4;
                end
                k = mod(q - 1, 4);
                st.unres     = false;
                st.corr_sent = true;
                st.quad_q    = q;
                st.quad_k    = k;
                st.pa_val    = true;
                st.pa_word(:)= T.fi(k * 0.25, 'phase');
            end
        end
    end

    st.cnt_i(:) = ci;
    st.cnt_q(:) = cq;

    % ---------------------------------------------------------------------
    % 6. PUBLIC LOCK DETECTOR (costas_top.sv lines 238-254)
    % ---------------------------------------------------------------------
    pub_clr = (~st_old.reported) || st_old.unres;
    if pub_clr
        st.lp = init_costas_hw_ld(uint32(8192), 12, 15);
    else
        thr_enter_pub = uint32(storedInteger(C.lock_pub(row).thr_enter));
        thr_exit_pub  = uint32(storedInteger(C.lock_pub(row).thr_exit));
        [st.lp, ~] = step_costas_hw_ld(st_old.lp, e_valid_r, e_reg_int, thr_enter_pub, thr_exit_pub);
    end

    out = costas_drive_outputs(st, T);
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================
function out = costas_drive_outputs(st, T)
    out.freq_adj_valid_o  = st.pw_val(end);
    out.freq_adj_o        = T.fi(st.pw_pi(end), 'freq_w');
    out.phase_adj_valid_o = st.pa_val;
    out.phase_adj_o       = st.pa_word;
    out.err_valid_o       = st.err_val;
    out.err_o             = st.err_reg;
    out.int_o             = st.acc;
    out.lock_o            = st.lp.locked && st.corr_sent && (~st.unres);
    out.internal_lock_o   = st.li.locked;
end

function [ai, aq] = fxp_slicer(yi, yq, use_qpsk, C)
    if use_qpsk
        if yi >= 0, ai = C.lvl_q; else, ai = -C.lvl_q; end
        if yq >= 0, aq = C.lvl_q; else, aq = -C.lvl_q; end
    else
        ai = slice_4pam_fxp(yi, C);
        aq = slice_4pam_fxp(yq, C);
    end
end

function a = slice_4pam_fxp(y, C)
    if y >= C.thr_16
        a = C.lvl_16b;
    elseif y >= 0
        a = C.lvl_16a;
    elseif y >= -C.thr_16
        a = -C.lvl_16a;
    else
        a = -C.lvl_16b;
    end
end

function [v, acc_next, sat_pos, sat_neg] = fxp_costas_pi(e_int, acc_int, Kp_int, Ki_int, sat_pos_prev, sat_neg_prev, T)
    % Bit-exact integer modeling of pi_filter.sv (pure truncation, no rounding)
    p_prop_r = e_int * Kp_int;
    p_int_r  = e_int * Ki_int;

    SHIFT = 7;
    p_prop_s = bitsra(p_prop_r, SHIFT);
    p_int_s  = bitsra(p_int_r, SHIFT);

    max_pi = int64(515396075); % 32'sh1EB8_51EB (0.12 * 2^32)

    acc_sum = acc_int + p_int_s;
    if acc_sum > max_pi
        acc_cand = max_pi;
    elseif acc_sum < -max_pi
        acc_cand = -max_pi;
    else
        acc_cand = acc_sum;
    end

    e_pos_1 = (e_int > 0);
    e_neg_1 = (e_int < 0);
    freeze  = (sat_pos_prev && e_pos_1) || (sat_neg_prev && e_neg_1);

    if ~freeze
        acc_next_int = acc_cand;
    else
        acc_next_int = acc_int;
    end

    v_sum = acc_next_int + p_prop_s;
    if v_sum > max_pi
        v_int   = max_pi;
        sat_pos = true;
        sat_neg = false;
    elseif v_sum < -max_pi
        v_int   = -max_pi;
        sat_pos = false;
        sat_neg = true;
    else
        v_int   = v_sum;
        sat_pos = false;
        sat_neg = false;
    end

    % Convert 32-bit Q0.32 integer to fi('freq_w')
    v = T.fi(double(v_int) * (2^-32), 'freq_w');
    acc_next = T.fi(double(acc_next_int) * (2^-32), 'freq_w');
end

function ld = init_costas_hw_ld(init_err_u16, confirm_cnt, min_syms)
    ld.m_acc       = uint32(init_err_u16) * uint32(16); % Alpha_Shift = 4
    ld.m           = T_lock_m_dummy(init_err_u16);
    ld.sym_cnt     = uint32(0);
    ld.bucket      = uint32(0);
    ld.locked      = false;
    ld.confirm     = uint32(confirm_cnt);
    ld.min_syms    = uint32(min_syms);
end

function m_val = T_lock_m_dummy(init_err_u16)
    m_val = double(init_err_u16) * (2^-15);
end

function [ld, lock_comb] = step_costas_hw_ld(ld_old, valid_i, e_int, thr_enter_u, thr_exit_u)
    % Bit-exact match to rtl/costas/lock_detector.sv (gen_single_cycle)
    ld = ld_old;
    if ~valid_i
        lock_comb = ld_old.locked;
        return;
    end

    e_abs  = uint32(abs(double(e_int)));
    m_acc0 = uint32(ld_old.m_acc);
    m_next = m_acc0 + e_abs - bitshift(m_acc0, -4);
    m_val  = bitshift(m_next, -4);

    idx_ok = (ld_old.min_syms == 0) || (ld_old.sym_cnt >= (ld_old.min_syms - 1));
    if ld_old.locked
        thr = thr_exit_u;
    else
        thr = thr_enter_u;
    end
    good = (m_val < thr) && idx_ok;

    b_old = uint32(ld_old.bucket);
    if good
        if b_old >= ld_old.confirm
            b_next = b_old;
        else
            b_next = b_old + 1;
        end
    elseif b_old >= 2
        b_next = b_old - 2;
    else
        b_next = uint32(0);
    end

    if b_next >= ld_old.confirm
        locked_comb = true;
    elseif b_next == 0
        locked_comb = false;
    else
        locked_comb = ld_old.locked;
    end

    ld.m_acc  = m_next;
    ld.m      = double(m_val) * (2^-15);
    ld.bucket = b_next;
    ld.locked = locked_comb;
    if ld_old.sym_cnt < ld_old.min_syms
        ld.sym_cnt = ld_old.sym_cnt + 1;
    end
    lock_comb = locked_comb;
end
