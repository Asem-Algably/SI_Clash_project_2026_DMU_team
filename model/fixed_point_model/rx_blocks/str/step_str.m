function [out, st] = step_str(in, st, T)
    % STEP_STR  Cycle-Accurate Fixed-Point Symbol Timing Recovery (str.md).
    % All datapath registers use pure 2's-complement wrapping ('wrap'); saturation is used ONLY in the PI filter.

    R  = T.rd;
    S  = T.str;
    Lp = T.lat.str;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & INITIALIZATION (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.Di      = T.fi(zeros(1, 3), 'in');             % 3 registers + input wire = 4-tap window
        st.Dq      = T.fi(zeros(1, 3), 'in');
        st.M       = T.fi(0.75, 'M');                     % Reset value M = 0.75 (str.md Section 2)
        st.W       = T.fi(0.25, 'M');                     % Reset value W = 0.25
        st.pi_reg  = T.fi(0, 'str_pi', 'sat');            % PI output feeding controller (saturated)
        st.acc     = T.fi(0, 'str_pi', 'sat');            % PI integrator (saturated)
        st.cur_i   = T.fi(0, 'str_sym');
        st.cur_q   = T.fi(0, 'str_sym');
        st.prev_i  = T.fi(0, 'str_sym');
        st.prev_q  = T.fi(0, 'str_sym');
        st.mid_i   = T.fi(0, 'str_sym');
        st.mid_q   = T.fi(0, 'str_sym');
        st.mu_reg  = T.fi(0, 'mu');
        st.t_phase = 0.0;
        st.smp_cnt = 0;
        st.smp_reg = 0;
        st.sym_cnt = T.fi(0, 'cnt');
        st.sat_cnt = T.fi(0, 'cnt');

        % Lumped Farrow interpolator pipeline (T.lat.str clocks)
        st.ip_cur  = false(1, Lp);
        st.ip_mid  = false(1, Lp);
        st.ip_yi   = T.fi(zeros(1, Lp), 'str_sym');
        st.ip_yq   = T.fi(zeros(1, Lp), 'str_sym');
        st.ip_mu   = T.fi(zeros(1, Lp), 'mu');
        st.ip_smp  = zeros(1, Lp);

        % Lock detector state (EMA + hysteresis + leaky bucket)
        st.lock.m        = T.fi(S.lock.m0, 'lock_m');
        st.lock.good     = false;
        st.lock.bucket   = T.fi(0, 'lock_b');
        st.lock.locked   = false;
        st.lock.lock_sym = NaN;

        st.te_val  = false;
        st.te_e    = T.fi(0, 'ted_e');

        out = str_drive_outputs(st, false);
        return;
    end

    % =====================================================================
    % 2. SNAPSHOT INTERNAL STATE (Read-Before-Write Safety)
    % =====================================================================
    st_old = st;

    % =====================================================================
    % 3. STROBE-GATED INPUT STAGE (Advances on s_axis_valid_i)
    % =====================================================================
    new_cur = false;
    new_mid = false;
    new_yi  = T.fi(0, 'str_sym');
    new_yq  = T.fi(0, 'str_sym');
    new_mu  = st_old.mu_reg;
    cur_smp = st_old.smp_cnt;

    if in.s_axis_valid_i
        cur_smp    = st_old.smp_cnt + 1;
        st.smp_cnt = cur_smp;

        xi = R(T.fi(in.s_axis_i_sample_i, 'in'));
        xq = R(T.fi(in.s_axis_q_sample_i, 'in'));

        W_use = st_old.W;
        if in.force_w_en_i
            W_use = T.fi(in.force_w_i, 'M');
        end

        % Pure fi two-region Modulo-1 boundary check using 25-bit signed wire M_s
        M_s   = R(T.fi(st_old.M, 'M_s'));
        W_s   = R(T.fi(W_use,    'M_s'));
        q25_s = R(T.fi(T.c.q25,  'M_s'));
        q75_s = R(T.fi(T.c.q75,  'M_s'));

        in_mid_old = (M_s >= q25_s) && (M_s < q75_s);
        M_next_val = T.fi(M_s - W_s, 'M');
        M_next_s   = R(T.fi(M_next_val, 'M_s'));
        in_mid_new = (M_next_s >= q25_s) && (M_next_s < q75_s);

        if in_mid_old && ~in_mid_new
            new_cur = true;
            eta_raw = M_s - q25_s;
        elseif ~in_mid_old && in_mid_new
            new_mid = true;
            if M_s >= q75_s
                eta_raw = M_s - q75_s;
            else
                eta_raw = M_s + q25_s;
            end
        else
            eta_raw = T.fi(0, 'M_s');
        end

        if new_cur || new_mid
            eta  = T.fi(eta_raw, 'eta');
            pm   = T.fi(R(st_old.pi_reg), 'pi_mu');
            mu_v = T.fi(R(eta) * T.c.k4 - (R(eta) * R(pm)) * T.c.k16m, 'mu');
            new_mu = mu_v;

            % Evaluate Farrow interpolator over 4-sample window [D1, D2, D3, x_new]
            new_yi = fxp_farrow_eval(R(st_old.Di(1)), R(st_old.Di(2)), R(st_old.Di(3)), xi, mu_v, T);
            new_yq = fxp_farrow_eval(R(st_old.Dq(1)), R(st_old.Dq(2)), R(st_old.Dq(3)), xq, mu_v, T);
        end

        % Shift 4-sample delay line and update modulo-1 counter M
        st.Di(:) = [R(st_old.Di(2:3)), xi];
        st.Dq(:) = [R(st_old.Dq(2:3)), xq];
        st.M(:)  = M_next_val;
    end

    % =====================================================================
    % 4. CLOCK-RATE PIPELINE SHIFT (Advances on EVERY clk_i)
    % =====================================================================
    st.ip_cur    = [new_cur,      st_old.ip_cur(1:end-1)];
    st.ip_mid    = [new_mid,      st_old.ip_mid(1:end-1)];
    st.ip_yi(:)  = [R(new_yi),    R(st_old.ip_yi(1:end-1))];
    st.ip_yq(:)  = [R(new_yq),    R(st_old.ip_yq(1:end-1))];
    st.ip_mu(:)  = [R(new_mu),    R(st_old.ip_mu(1:end-1))];
    st.ip_smp    = [cur_smp,      st_old.ip_smp(1:end-1)];

    % =====================================================================
    % 5. STROBE SAMPLER, GARDNER TED, PI FILTER & LOCK DETECTOR (At Tail)
    % =====================================================================
    tail_cur = st_old.ip_cur(end);
    tail_mid = st_old.ip_mid(end);
    yt_i     = R(st_old.ip_yi(end));
    yt_q     = R(st_old.ip_yq(end));
    yt_mu    = st_old.ip_mu(end);
    yt_smp   = st_old.ip_smp(end);

    sym_valid  = false;
    st.te_val  = false;

    if tail_mid
        st.mid_i(:) = yt_i;
        st.mid_q(:) = yt_q;
    end

    if tail_cur
        sym_valid     = true;
        st.prev_i(:)  = R(st_old.cur_i);
        st.prev_q(:)  = R(st_old.cur_q);
        st.cur_i(:)   = yt_i;
        st.cur_q(:)   = yt_q;
        st.mu_reg(:)  = yt_mu;
        st.sym_cnt(:) = R(st_old.sym_cnt) + 1;
        cnt_new       = double(st.sym_cnt);
        st.smp_reg    = yt_smp;
        st.t_phase    = ((yt_smp - 3) + double(yt_mu)) / T.sps - (cnt_new - 1);

        % Gardner TED (pure wrap with guard bits in ted_d and ted_e)
        d_i = T.fi(yt_i - R(st_old.cur_i), 'ted_d');
        d_q = T.fi(yt_q - R(st_old.cur_q), 'ted_d');
        e_t = T.fi(R(st_old.mid_i) * R(d_i) + R(st_old.mid_q) * R(d_q), 'ted_e');
        st.te_val  = true;
        st.te_e(:) = e_t;

        % PI loop filter (the ONLY block with saturation & anti-windup)
        [v_pi, acc_new, sat_f] = fxp_pi_step(R(e_t), R(st_old.acc), S.kp, S.ki, S.max_v_pi, T, 'str_pi');
        st.acc(:)    = acc_new;
        st.pi_reg(:) = v_pi;
        if sat_f
            st.sat_cnt(:) = R(st_old.sat_cnt) + 1;
        end

        if S.open_loop
            st.W(:) = T.c.q25;
        else
            q25_s   = R(T.fi(T.c.q25, 'M_s'));
            st.W(:) = T.fi(q25_s + R(v_pi), 'M');
        end

        % Continuous Hardware Lock Detector
        st.lock = fxp_lock_step(st_old.lock, e_t, S.lock, cnt_new, T);
    end

    out = str_drive_outputs(st, sym_valid);
end

function out = str_drive_outputs(st, sym_valid)
    out.m_axis_valid_o  = sym_valid;
    out.m_axis_i_sym_o  = st.cur_i;
    out.m_axis_q_sym_o  = st.cur_q;
    out.lock_o          = st.lock.locked;
    out.ted_err_valid_o = st.te_val;
    out.ted_err_o       = st.te_e;
    out.mu_o            = st.mu_reg;
    out.w_o             = st.W;
end

function y = fxp_farrow_eval(a, b, c, d, mu, T)
    % 4-Tap Piecewise-Parabolic Farrow Interpolator (alpha = 0.5)
    % Hardware Datapath:
    %   v2 = 0.5 * (d - c - b + a)
    %   v1 = 0.5 * (3*c - d - b - a)
    %   h1 = v2 * mu + v1
    %   y  = h1 * mu + b
    R    = T.rd;
    mu   = R(mu);
    half = T.c.half;

    c3 = R(c) + R(c) + R(c);
    v2 = T.fi((R(d) - R(c) - R(b) + R(a)) * half, 'fv');
    v1 = T.fi((c3 - R(d) - R(b) - R(a)) * half,   'fv');
    h1 = T.fi(R(v2) * mu + R(v1), 'fh');
    y  = T.fi(R(h1) * mu + R(b),  'str_sym');
end

function [v, acc_next, sat] = fxp_pi_step(e, acc, Kp, Ki, lim, T, tname)
    acc_c = T.fi(acc + Ki * e, tname, 'sat');
    if acc_c > lim
        acc_c(:) = lim;
    elseif acc_c < -lim
        acc_c(:) = -lim;
    end
    v_raw = Kp * e + T.rd(acc_c);
    sat   = false;
    if v_raw > lim
        sat = true;
        v   = T.fi(lim, tname, 'sat');
        if e > 0, acc_next = T.fi(acc, tname, 'sat'); else, acc_next = acc_c; end
    elseif v_raw < -lim
        sat = true;
        v   = T.fi(-lim, tname, 'sat');
        if e < 0, acc_next = T.fi(acc, tname, 'sat'); else, acc_next = acc_c; end
    else
        v        = T.fi(v_raw, tname, 'sat');
        acc_next = acc_c;
    end
end

function ld = fxp_lock_step(ld_old, e, p, sym_idx, T)
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
        if ~ld_old.locked && isnan(ld_old.lock_sym)
            ld.lock_sym = sym_idx;
        end
        ld.locked = true;
    elseif b_new == 0
        ld.locked = false;
    end
end
