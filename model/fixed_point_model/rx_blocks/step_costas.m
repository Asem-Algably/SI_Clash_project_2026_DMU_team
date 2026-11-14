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
        st.acc       = T.fi(0, 'cos_pi', 'sat');
        st.pw_val    = false(1, Lc);
        st.pw_pi     = T.fi(zeros(1, Lc), 'cos_pi', 'sat');
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
    new_pw_pi   = T.fi(0, 'cos_pi', 'sat');
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
        if in.s_axis_valid_i
            yi = R(T.fi(in.s_axis_i_sym_i, 'rot_out'));
            yq = R(T.fi(in.s_axis_q_sym_i, 'rot_out'));
            [ai, aq] = fxp_slicer(yi, yq, true, C);
            st.ai    = ai;
            st.aq    = aq;
            st.a_ref = (double(ai) + 1j * double(aq)) / T.in_scale;
        end
    else
        if in.s_axis_valid_i
            yi = R(T.fi(in.s_axis_i_sym_i, 'rot_out'));
            yq = R(T.fi(in.s_axis_q_sym_i, 'rot_out'));

            [ai, aq]      = fxp_slicer(yi, yq, use_qpsk, C);
            st.ai         = ai;
            st.aq         = aq;
            st.a_ref      = (double(ai) + 1j * double(aq)) / T.in_scale;
            e_raw         = T.fi(yq * R(ai) - yi * R(aq), 'cos_e');
            st.err_val    = true;
            st.err_reg(:) = e_raw;

            % PI Loop Filter (the ONLY block with saturation & anti-windup)
            [v_pi, acc_new, sat_c] = fxp_costas_pi(R(e_raw), R(st_old.acc), C.kp{row}, C.ki{row}, C.max_pi, T);
            st.acc(:) = acc_new;
            if sat_c
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

function [v, acc_next, sat] = fxp_costas_pi(e, acc, Kp, Ki, lim, T)
    acc_c = T.fi(acc + Ki * e, 'cos_pi', 'sat');
    if acc_c > lim
        acc_c(:) = lim;
    elseif acc_c < -lim
        acc_c(:) = -lim;
    end
    v_raw = Kp * e + T.rd(acc_c);
    sat   = false;
    if v_raw > lim
        sat = true;
        v   = T.fi(lim, 'cos_pi', 'sat');
        if e > 0, acc_next = T.fi(acc, 'cos_pi', 'sat'); else, acc_next = acc_c; end
    elseif v_raw < -lim
        sat = true;
        v   = T.fi(-lim, 'cos_pi', 'sat');
        if e < 0, acc_next = T.fi(acc, 'cos_pi', 'sat'); else, acc_next = acc_c; end
    else
        v        = T.fi(v_raw, 'cos_pi', 'sat');
        acc_next = acc_c;
    end
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
