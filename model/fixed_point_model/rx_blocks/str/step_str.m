function [out, st] = step_str(in, st, T)
    % STEP_STR  Cycle-Accurate & Interface-Accurate Symbol Timing Recovery (str.md).
    %
    % Ports (in):
    %   rst_ni, s_axis_valid_i, s_axis_i_sample_i, s_axis_q_sample_i (Q1.11),
    %   loop_gain_i (8-bit), force_w_en_i, force_w_i
    % Ports (out):
    %   m_axis_valid_o, m_axis_i_sym_o, m_axis_q_sym_o (Q2.14), lock_o,
    %   ted_err_valid_o, ted_err_o, mu_o, w_o

    R  = T.rd;
    S  = T.str;
    Lp = T.lat.str;

    % =====================================================================
    % 1. ACTIVE-LOW RESET & INITIALIZATION (~rst_ni)
    % =====================================================================
    if isempty(st) || ~in.rst_ni
        st.Di      = T.fi(zeros(1, 3), 'in', 'sat');      % 3 registers + input wire = 4-tap window
        st.Dq      = T.fi(zeros(1, 3), 'in', 'sat');
        st.M       = T.fi(0.75, 'M', 'wrap');             % Reset value M = 0.75 (str.md Section 2)
        st.W       = T.fi(0.25, 'M', 'sat');              % Reset value W = 0.25
        st.pi_reg  = T.fi(0, 'str_pi', 'sat');            % PI output feeding controller
        st.acc     = T.fi(0, 'str_pi', 'sat');            % PI integrator
        st.cur_i   = T.fi(0, 'str_sym', 'sat');
        st.cur_q   = T.fi(0, 'str_sym', 'sat');
        st.prev_i  = T.fi(0, 'str_sym', 'sat');
        st.prev_q  = T.fi(0, 'str_sym', 'sat');
        st.mid_i   = T.fi(0, 'str_sym', 'sat');
        st.mid_q   = T.fi(0, 'str_sym', 'sat');
        st.mu_reg  = T.fi(0, 'mu', 'sat');
        st.t_phase = 0.0;                                 % Exact timing phase diagnostic
        st.smp_cnt = 0;                                   % Input sample counter for diagnostic
        st.sym_cnt = T.fi(0, 'cnt', 'sat');
        st.sat_cnt = T.fi(0, 'cnt', 'sat');

        % Lumped Farrow interpolator pipeline (T.lat.str clocks)
        st.ip_cur  = false(1, Lp);
        st.ip_mid  = false(1, Lp);
        st.ip_yi   = T.fi(zeros(1, Lp), 'str_sym', 'sat');
        st.ip_yq   = T.fi(zeros(1, Lp), 'str_sym', 'sat');
        st.ip_mu   = T.fi(zeros(1, Lp), 'mu', 'sat');
        st.ip_smp  = zeros(1, Lp);

        % Lock detector state (EMA + hysteresis + leaky bucket)
        st.lock.m      = T.fi(S.lock.m0, 'lock_m', 'sat');
        st.lock.good   = false;
        st.lock.bucket = T.fi(0, 'lock_b', 'sat');
        st.lock.locked = false;
        st.lock.lock_sym = NaN;

        st.te_val  = false;
        st.te_e    = T.fi(0, 'ted_e', 'sat');

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
    new_yi  = T.fi(0, 'str_sym', 'sat');
    new_yq  = T.fi(0, 'str_sym', 'sat');
    new_mu  = st_old.mu_reg;
    cur_smp = st_old.smp_cnt;

    if in.s_axis_valid_i
        cur_smp    = st_old.smp_cnt + 1;
        st.smp_cnt = cur_smp;

        xi = R(T.fi(in.s_axis_i_sample_i, 'in', 'sat'));
        xq = R(T.fi(in.s_axis_q_sample_i, 'in', 'sat'));

        W_use = st_old.W;
        if in.force_w_en_i
            W_use = T.fi(in.force_w_i, 'M', 'sat');
        end

        % Pure fi two-region Modulo-1 boundary check using 25-bit signed wire M_s
        M_s   = R(T.fi(st_old.M, 'M_s', 'sat'));
        W_s   = R(T.fi(W_use,    'M_s', 'sat'));
        q25_s = R(T.fi(T.c.q25,  'M_s', 'sat'));
        q75_s = R(T.fi(T.c.q75,  'M_s', 'sat'));

        in_mid_old = (M_s >= q25_s) && (M_s < q75_s);
        M_next_val = T.wrapf(T.fi(M_s - W_s, 'M', 'wrap'));
        M_next_s   = R(T.fi(M_next_val, 'M_s', 'sat'));
        in_mid_new = (M_next_s >= q25_s) && (M_next_s < q75_s);

        if in_mid_old && ~in_mid_new
            new_cur = true;
            eta_raw = M_s - q25_s;
        elseif ~in_mid_old && in_mid_new
            new_mid = true;
            if M_s >= q75_s
                eta_raw = M_s - q75_s;
            else
                % Wrapped across 0 -> 1 boundary while crossing 0.75
                eta_raw = M_s + q25_s;
            end
        else
            eta_raw = T.fi(0, 'M_s', 'sat');
        end

        if new_cur || new_mid
            eta = T.fi(eta_raw, 'eta', 'sat');
            if S.mu_exact
                mu_v = T.fi(double(eta) / double(W_use), 'mu', 'sat');
            else
                % Pure fi RTL linear form: mu = 4*eta - 16*eta*pi
                pm   = T.fi(R(st_old.pi_reg), 'pi_mu', 'sat');
                mu_v = T.fi(R(eta) * T.c.k4 - (R(eta) * R(pm)) * T.c.k16m, 'mu', 'sat');
            end
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
        st.t_phase    = ((yt_smp - 3) + double(yt_mu)) / T.sps - (cnt_new - 1);

        % Gardner TED: e = Re{mid}*(Re{cur} - Re{prev}) + Im{mid}*(Im{cur} - Im{prev})
        d_i = T.fi(yt_i - R(st_old.cur_i), 'ted_d', 'sat');
        d_q = T.fi(yt_q - R(st_old.cur_q), 'ted_d', 'sat');
        e_t = T.fi(R(st_old.mid_i) * R(d_i) + R(st_old.mid_q) * R(d_q), 'ted_e', 'sat');
        st.te_val  = true;
        st.te_e(:) = e_t;

        % PI loop filter with saturation & conditional anti-windup
        [v_pi, acc_new, sat_f] = fxp_pi_step(R(e_t), R(st_old.acc), S.kp, S.ki, S.max_v_pi, T, 'str_pi');
        st.acc(:)    = acc_new;
        st.pi_reg(:) = v_pi;
        if sat_f
            st.sat_cnt(:) = R(st_old.sat_cnt) + 1;
        end

        if S.open_loop
            st.W(:) = T.c.q25;
        else
            q25_s   = R(T.fi(T.c.q25, 'M_s', 'sat'));
            st.W(:) = T.fi(q25_s + R(v_pi), 'M', 'sat');
        end

        % Continuous Hardware Lock Detector (str.md Section 3)
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
    R    = T.rd;
    mu   = R(mu);
    half = T.c.half; % Exact 1-bit wire right-shift (ufix1_En1 in fi)

    if T.str.interp_cubic
        k16 = R(T.c.k16); k13 = R(T.c.k13);
        v3 = T.fi((R(b) - R(c)) * half + (R(d) - R(a)) * k16,          'fv', 'sat');
        v2 = T.fi((R(c) + R(a)) * half - R(b),                         'fv', 'sat');
        v1 = T.fi(R(c) - R(b) * half - R(d) * k16 - R(a) * k13,        'fv', 'sat');
        h1 = T.fi(R(v3) * mu + R(v2), 'fh', 'sat');
        h2 = T.fi(R(h1) * mu + R(v1), 'fh', 'sat');
        y  = T.fi(R(h2) * mu + R(b),  'str_sym', 'sat');
    else
        % Parabolic Farrow (str.md Section 3.1):
        % 3*c is formed in FullPrecision fi (R(c)+R(c)+R(c)) so it never clips to Q1.11 before Q4.12 ('fv')!
        c3 = R(c) + R(c) + R(c);
        v2 = T.fi((R(d) - R(c) - R(b) + R(a)) * half,                  'fv', 'sat');
        v1 = T.fi((c3 - R(d) - R(b) - R(a)) * half,                    'fv', 'sat');
        h1 = T.fi(R(v2) * mu + R(v1), 'fh', 'sat');
        y  = T.fi(R(h1) * mu + R(b),  'str_sym', 'sat');
    end
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
    m_old = R(ld_old.m);
    d     = a - m_old;
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
