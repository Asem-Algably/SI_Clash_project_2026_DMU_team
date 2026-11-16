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
        st.pw_val    = false(1, Lc);
        st.pw_pi     = T.fi(zeros(1, Lc), 'freq_w');
        st.sat_pos   = false;
        st.sat_neg   = false;
        st.li        = init_costas_ld(T, C.lock_int(1).m0);
        st.lp        = init_costas_ld(T, C.lock_pub(1).m0);
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

    new_pw_val  = false;
    new_pw_pi   = T.fi(0, 'freq_w');
    new_pa_val  = false;
    new_pa_word = T.fi(0, 'phase');
    st.err_val  = false;

    ci = R(st_old.cnt_i);
    cq = R(st_old.cnt_q);

    if mode == MODE_HOLD
        ci = 0;
        cq = 0;
        st.reported  = false;
        st.corr_sent = false;
        st.unres     = false;
        st.sat_pos   = false;
        st.sat_neg   = false;
        st.acc(:)    = T.fi(0, 'freq_w');
        if in.s_axis_valid_i
            st.sym_cnt = st_old.sym_cnt + 1;
            yi = R(T.fi(in.s_axis_i_sym_i, 'rot_out'));
            yq = R(T.fi(in.s_axis_q_sym_i, 'rot_out'));
            [ai, aq] = fxp_slicer(yi, yq, true, C);
            st.ai    = ai;
            st.aq    = aq;
            st.a_ref = (double(ai) + 1j * double(aq)) / T.in_scale;
        end
    else
        if in.s_axis_valid_i
            st.sym_cnt = st_old.sym_cnt + 1;
            yi = R(T.fi(in.s_axis_i_sym_i, 'rot_out'));
            yq = R(T.fi(in.s_axis_q_sym_i, 'rot_out'));

            [ai, aq]      = fxp_slicer(yi, yq, use_qpsk, C);
            st.ai         = ai;
            st.aq         = aq;
            st.a_ref      = (double(ai) + 1j * double(aq)) / T.in_scale;

            % Phase Error Detector matching phase_error.sv
            yi_int = int64(storedInteger(yi));
            yq_int = int64(storedInteger(yq));
            ai_int = int64(storedInteger(ai));
            aq_int = int64(storedInteger(aq));

            m_qa = yq_int * ai_int;
            m_ia = yi_int * aq_int;
            diff_r = m_qa - m_ia;
            % Pure wire truncation matching phase_error.sv
            shifted = bitsra(diff_r, 15);
            if shifted > 32767
                e_int = int64(32767);
            elseif shifted < -32768
                e_int = int64(-32768);
            else
                e_int = shifted;
            end
            e_raw = T.fi(double(e_int) * (2^-15), 'cos_e');
            st.err_val    = true;
            st.err_reg(:) = e_raw;

            % Select loop gains matching costas_top.sv
            if mode == T.enc.mode.ACQ
                kp_int = int64(220364);
                ki_int = int64(7347);
            else
                if use_qpsk
                    kp_int = int64(220364);
                    ki_int = int64(7347);
                else
                    kp_int = int64(396656);
                    ki_int = int64(13224);
                end
            end

            % PI Loop Filter matching pi_filter.sv (pure truncation, no rounding)
            sat_pos_prev = isfield(st_old, 'sat_pos') && logical(st_old.sat_pos);
            sat_neg_prev = isfield(st_old, 'sat_neg') && logical(st_old.sat_neg);
            acc_cur_int  = int64(storedInteger(st_old.acc));

            [v_pi, acc_new, sat_pos, sat_neg] = fxp_costas_pi(...
                e_int, acc_cur_int, kp_int, ki_int, sat_pos_prev, sat_neg_prev, T);

            st.acc(:)    = acc_new;
            st.sat_pos   = sat_pos;
            st.sat_neg   = sat_neg;
            if sat_pos || sat_neg
                st.sat_cnt = st_old.sat_cnt + 1;
            end
            new_pw_val = true;
            new_pw_pi  = v_pi;

            st.li = step_costas_ld(st_old.li, e_raw, C.lock_int(row), T);

            if ~st_old.reported
                if ~st.li.locked
                    ci = 0;
                    cq = 0;
                else
                    if R(ai) >= 0, si = 1; else, si = -1; end
                    if R(aq) >= 0, sq = 1; else, sq = -1; end
                    ci = min(max(ci + si, C.cnt_full_neg), C.cnt_full_pos);
                    cq = min(max(cq + sq, C.cnt_full_neg), C.cnt_full_pos);
                end
            else
                if ~st_old.unres
                    st.lp = step_costas_ld(st_old.lp, e_raw, C.lock_pub(row), T);
                end
            end
        end

        if ~st_old.reported
            c_full  = (ci >= C.cnt_full_pos) || (ci <= C.cnt_full_neg) || ...
                      (cq >= C.cnt_full_pos) || (cq <= C.cnt_full_neg);
            do_eval = (c_full && (ci ~= 0) && (cq ~= 0) && in.s_axis_valid_i) || logical(in.preamble_end_i);
            if do_eval
                st.reported = true;
                if (ci == 0) || (cq == 0)
                    st.unres  = true;
                    st.quad_q = NaN;
                    st.quad_k = NaN;
                else
                    if ci > 0 && cq > 0
                        q = 1;
                    elseif ci < 0 && cq > 0
                        q = 2;
                    elseif ci < 0 && cq < 0
                        q = 3;
                    else
                        q = 4;
                    end
                    k = mod(q - 1, 4);
                    st.unres  = false;
                    st.quad_q = q;
                    st.quad_k = k;
                    new_pa_val  = true;
                    new_pa_word = T.fi(k * 0.25, 'phase');
                end
                st.corr_sent = ~st.unres;
                st.lp        = init_costas_ld(T, C.lock_pub(row).m0);
            end
        end
    end

    st.cnt_i(:)   = ci;
    st.cnt_q(:)   = cq;
    st.pa_val     = new_pa_val;
    st.pa_word(:) = new_pa_word;
    st.pw_val     = [new_pw_val,   st_old.pw_val(1:end-1)];
    st.pw_pi(:)   = [R(new_pw_pi), R(st_old.pw_pi(1:end-1))];

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

function ld = init_costas_ld(T, m0)
    ld.m      = T.fi(m0, 'lock_m');
    ld.good   = false;
    ld.bucket = T.fi(0, 'lock_b');
    ld.locked = false;
end

function ld = step_costas_ld(ld_old, e, p, T)
    R  = T.rd;
    ld = ld_old;
    a  = R(e);
    if a < 0, a = -a; end
    m_old   = R(ld_old.m);
    d       = a - m_old;
    ld.m(:) = m_old + bitsra(d, p.ema_shift);

    m_new = R(ld.m);
    if ld_old.good
        if m_new > R(p.thr_exit),  ld.good = false; end
    else
        if m_new < R(p.thr_enter), ld.good = true;  end
    end

    b_old = double(ld_old.bucket);
    if ld.good
        b_new = min(b_old + 1, p.confirm);
    else
        b_new = max(b_old - 2, 0);
    end
    ld.bucket(:) = b_new;

    if b_new >= p.confirm
        ld.locked = true;
    elseif b_new == 0
        ld.locked = false;
    end
end
