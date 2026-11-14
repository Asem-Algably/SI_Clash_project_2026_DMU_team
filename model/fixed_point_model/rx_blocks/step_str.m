function [out, st] = step_str(in, st, T)
    % STEP_STR  Cycle-Accurate Fixed-Point Symbol Timing Recovery Module.
    %
    % Self-contained hardware implementation of STR containing:
    %   1. Modulo-1 NCO Counter & Controller (M reset = 0.75, W reset = 0.25)
    %   2. 3-Tap Parabolic Farrow Interpolator (Horner MAC structure)
    %   3. 4-Stage Strobe & Sample Pipeline Shift Register
    %   4. Gardner Timing Error Detector (TED)
    %   5. Saturating PI Loop Filter with Anti-Windup
    %   6. Leaky Bucket Lock Detector

    R  = T.rd;
    Lp = T.lat.str; % 4 cycles

    % =====================================================================
    % 1. ACTIVE-LOW RESET (~rst_ni)
    % =====================================================================
    if ~in.rst_ni
        st.Di      = T.fi(zeros(1, 3), 'in');             % 3 registers + input wire = 4-tap window
        st.Dq      = T.fi(zeros(1, 3), 'in');
        st.M       = T.fi(0.75, 'M');                     % Reset value M = 0.75
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

        % Lumped Farrow interpolator pipeline (Lp clocks)
        st.ip_cur  = false(1, Lp);
        st.ip_mid  = false(1, Lp);
        st.ip_yi   = T.fi(zeros(1, Lp), 'str_sym');
        st.ip_yq   = T.fi(zeros(1, Lp), 'str_sym');
        st.ip_mu   = T.fi(zeros(1, Lp), 'mu');
        st.ip_smp  = zeros(1, Lp);

        % Lock detector state (EMA + hysteresis + leaky bucket)
        st.lock.m        = T.fi(T.lock.str_m0, 'lock_m');
        st.lock.good     = false;
        st.lock.bucket   = T.fi(0, 'lock_b');
        st.lock.locked   = false;
        st.lock.lock_sym = NaN;

        st.out_valid = false;
        st.te_val    = false;
        st.te_e      = T.fi(0, 'ted_e');

        out = str_drive_outputs(st);
        return;
    end

    st_old = st;

    % =====================================================================
    % 2. STR CLOCK ENABLE (ce_str = s_axis_valid_i | flush_active)
    % =====================================================================
    flush_active = isfield(in, 'flush_active') && logical(in.flush_active);
    valid_scheme = ~isfield(T, 'valid') || ~isfield(T.valid, 'enable') || logical(T.valid.enable);

    if valid_scheme
        ce_str = logical(in.s_axis_valid_i) || flush_active;
    else
        ce_str = true;
    end

    % When ce_str = 0: STR is completely frozen.
    % Only st.out_valid clears to false (registered pulse); all data registers hold.
    if ~ce_str
        st = st_old;
        st.out_valid = false;
        st.te_val    = false;
        out = str_drive_outputs(st);
        return;
    end

    % =====================================================================
    % 3. MODULO-1 NCO & INTERPOLATION (On ce_str)
    % =====================================================================
    new_cur = false;
    new_mid = false;
    new_yi  = T.fi(0, 'str_sym');
    new_yq  = T.fi(0, 'str_sym');
    new_mu  = st_old.mu_reg;
    cur_smp = st_old.smp_cnt;

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

        % Evaluate Parabolic Farrow interpolator over 4-sample window [D1, D2, D3, xi]
        new_yi = farrow_eval(R(st_old.Di(1)), R(st_old.Di(2)), R(st_old.Di(3)), xi, mu_v, T);
        new_yq = farrow_eval(R(st_old.Dq(1)), R(st_old.Dq(2)), R(st_old.Dq(3)), xq, mu_v, T);
    end

    % Shift 4-sample delay line and update modulo-1 counter M
    st.Di(:) = [R(st_old.Di(2:3)), xi];
    st.Dq(:) = [R(st_old.Dq(2:3)), xq];
    st.M(:)  = M_next_val;

    % =====================================================================
    % 4. CLOCK-RATE PIPELINE SHIFT (Advances on ce_str)
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

    st.out_valid = tail_cur;
    st.te_val    = false;

    if tail_mid
        st.mid_i(:) = yt_i;
        st.mid_q(:) = yt_q;
    end

    if tail_cur
        st.prev_i(:)  = R(st_old.cur_i);
        st.prev_q(:)  = R(st_old.cur_q);
        st.cur_i(:)   = yt_i;
        st.cur_q(:)   = yt_q;
        st.mu_reg(:)  = yt_mu;
        st.sym_cnt(:) = R(st_old.sym_cnt) + 1;
        cnt_new       = double(st.sym_cnt);
        st.smp_reg    = yt_smp;
        st.t_phase    = ((yt_smp - 3) + double(yt_mu)) / T.sps - (cnt_new - 1);

        % Gardner TED: e = Re{mid}*(Re{cur} - Re{prev}) + Im{mid}*(Im{cur} - Im{prev})
        d_i = T.fi(yt_i - R(st_old.cur_i), 'ted_d');
        d_q = T.fi(yt_q - R(st_old.cur_q), 'ted_d');
        e_t = T.fi(R(st_old.mid_i) * R(d_i) + R(st_old.mid_q) * R(d_q), 'ted_e');
        st.te_val  = true;
        st.te_e(:) = e_t;

        % PI loop filter with saturation & conditional anti-windup
        [v_pi, acc_new, sat_f] = str_pi_filter(e_t, st_old.acc, T.str.kp, T.str.ki, T.str.max_pi, T);
        st.acc(:)    = acc_new;
        st.pi_reg(:) = v_pi;
        if sat_f
            st.sat_cnt(:) = R(st_old.sat_cnt) + 1;
        end

        q25_s   = R(T.fi(T.c.q25, 'M_s'));
        st.W(:) = T.fi(q25_s + R(v_pi), 'M');

        % Continuous Hardware Lock Detector
        st.lock = str_lock_step(st_old.lock, e_t, cnt_new, T);
    end

    out = str_drive_outputs(st);
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================
function out = str_drive_outputs(st)
    out.m_axis_valid_o  = st.out_valid;
    out.m_axis_i_sym_o  = st.cur_i;
    out.m_axis_q_sym_o  = st.cur_q;
    out.lock_o          = st.lock.locked;
    out.ted_err_valid_o = st.te_val;
    out.ted_err_o       = st.te_e;
    out.mu_o            = st.mu_reg;
    out.w_o             = st.W;
end

function y = farrow_eval(a, b, c, d, mu, T)
    % 3-Tap Parabolic Farrow Horner MAC (alpha = 0.5)
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

function [v, acc_next, sat] = str_pi_filter(e, acc, Kp, Ki, lim, T)
    R     = T.rd;
    acc_c = T.fi(R(acc) + R(Ki) * R(e), 'str_pi', 'sat');
    if acc_c > lim
        acc_c(:) = lim;
    elseif acc_c < -lim
        acc_c(:) = -lim;
    end
    v_raw = R(Kp) * R(e) + R(acc_c);
    sat   = false;
    if v_raw > lim
        sat = true;
        v   = T.fi(lim, 'str_pi', 'sat');
        if e > 0, acc_next = T.fi(acc, 'str_pi', 'sat'); else, acc_next = acc_c; end
    elseif v_raw < -lim
        sat = true;
        v   = T.fi(-lim, 'str_pi', 'sat');
        if e < 0, acc_next = T.fi(acc, 'str_pi', 'sat'); else, acc_next = acc_c; end
    else
        v        = T.fi(v_raw, 'str_pi', 'sat');
        acc_next = acc_c;
    end
end

function ld = str_lock_step(ld_old, e, sym_idx, T)
    R  = T.rd;
    ld = ld_old;
    a  = R(e);
    if a < 0, a = -a; end
    m_old   = R(ld_old.m);
    d       = a - m_old;
    ld.m(:) = m_old + bitsra(d, T.lock.ema_shift);

    m_new = R(ld.m);
    if ld_old.good
        if m_new > R(T.lock.str_thr_exit),  ld.good = false; end
    else
        if m_new < R(T.lock.str_thr_enter), ld.good = true;  end
    end

    b_old = double(ld_old.bucket);
    if ld.good
        b_new = min(b_old + 1, T.lock.str_confirm);
    else
        b_new = max(b_old - 2, 0);
    end
    ld.bucket(:) = b_new;

    if b_new >= T.lock.str_confirm
        if ~ld_old.locked && isnan(ld_old.lock_sym)
            ld.lock_sym = sym_idx;
        end
        ld.locked = true;
    elseif b_new == 0
        ld.locked = false;
    end
end
