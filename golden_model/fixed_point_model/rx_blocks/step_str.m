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

        % Lock detector state matching lock_detector.sv (3-stage pipeline)
        st.lock.v1       = false;
        st.lock.v2       = false;
        st.lock.e_abs_r  = 0;
        st.lock.m_acc    = uint32(254691) * 16; % AW'(Init_Error) << Alpha_Shift
        st.lock.m_val_r  = uint32(254691);
        st.lock.sym_cnt  = 0;
        st.lock.bucket   = 0;
        st.lock.locked   = false;
        st.lock.locked_q = false;
        st.lock.lock_sym = NaN;

        st.out_valid = false;
        st.mid_d     = false;
        st.y_i       = T.fi(0, 'str_sym');
        st.y_q       = T.fi(0, 'str_sym');
        st.te_val    = false;
        st.te_e      = T.fi(0, 'ted_e');

        % Hardware feedback pipeline (cfg.lat.ted = 2, cfg.lat.str_pi = 2)
        st.pipe_ted_val = false(1, 2);
        st.pipe_ted_e   = T.fi(zeros(1, 2), 'ted_e');
        st.pipe_pi_val  = false(1, 2);
        st.pipe_pi      = T.fi(zeros(1, 2), 'str_pi', 'sat');
        st.pipe_pi_e    = T.fi(0, 'ted_e');

        out = str_drive_outputs(st, in, T);
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

    % When ce_str = 0: str_top clears output strobe registers (curr_strobe_pipe[3],
    % mid_strobe_pipe[3]) while freezing Farrow, modulo,TED & symbol capture.
    % pI_loop and lock_detector advance their un-gated synchronous stages.
    if ~ce_str
        st = st_old;
        st.out_valid = false;
        st.mid_d     = false;
        st.te_val    = st_old.te_val;

        % pI_loop Stage 1 receives valid_i = ted_error_valid && ce_str = false;
        % Stage 2 updates acc and pi_reg if v_stg1_q was asserted previously.
        if st_old.pipe_pi_val(1)
            [v_pi, acc_new, sat_f] = str_pi_filter(st_old.pipe_pi_e, st_old.acc, T.str.kp, T.str.ki, T.str.max_pi, T);
            st.acc(:)    = acc_new;
            st.pi_reg(:) = R(v_pi);
            q25_s        = R(T.fi(T.c.q25, 'M_s'));
            st.W(:)      = T.fi(q25_s + R(v_pi), 'M');
            if sat_f
                st.sat_cnt(:) = R(st_old.sat_cnt) + 1;
            end
        end
        st.pipe_pi_val = [false, false];

        st.lock          = str_lock_hw_step(st_old.lock, false, st_old.te_e, double(st_old.sym_cnt), T);
        st.lock.locked_q = st.lock.locked;

        out = str_drive_outputs(st, in, T);
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

    % Wait: force_w_en_i in str_top.sv is strictly an output mux on w_o; internal NCO M always uses st_old.W.
    W_use = st_old.W;

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
        % Exact hardware-aligned 24-bit mu calculation matching modulo_1_controller.sv
        eta_raw_val = mod(double(storedInteger(eta_raw)), 2^24);
        eta_4x      = mod(eta_raw_val * 4, 2^24);
        pi_val      = double(bitsra(int64(storedInteger(st_old.pi_reg)), 4));
        eta_pi_mult = eta_raw_val * pi_val;
        term2_u     = mod(double(bitsra(int64(eta_pi_mult), 20)), 2^24);
        if term2_u >= 2^23
            term2 = term2_u - 2^24;
        else
            term2 = term2_u;
        end
        mu_full     = eta_4x - term2;
        if mu_full < 0
            mu_int = 0;
        elseif mu_full >= 2^24
            mu_int = 1023;
        else
            mu_int = floor(mu_full / (2^14));
        end
        mu_v = T.fi(0, 'mu');
        mu_v.int = int32(mu_int);
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
    % 5. STROBE SAMPLER, GARDNER TED, PI FILTER & LOCK DETECTOR (RTL-Aligned)
    % =====================================================================
    tail_cur = st_old.ip_cur(end);
    tail_mid = st_old.ip_mid(end);
    yt_i     = R(st_old.ip_yi(end));
    yt_q     = R(st_old.ip_yq(end));
    yt_mu    = st_old.ip_mu(end);
    yt_smp   = st_old.ip_smp(end);

    % Registered outputs of Stage 6 (curr_strobe_pipe[3], mid_strobe_pipe[3], i_y, q_y)
    st.out_valid = tail_cur;
    st.mid_d     = tail_mid;
    st.y_i(:)    = yt_i;
    st.y_q(:)    = yt_q;
    if tail_cur
        st.mu_reg(:)  = yt_mu;
        st.sym_cnt(:) = R(st_old.sym_cnt) + 1;
        cnt_new       = double(st.sym_cnt);
        st.smp_reg    = yt_smp;
        st.t_phase    = ((yt_smp - 3) + double(yt_mu)) / T.sps - (cnt_new - 1);
    end

    % Symbol registers (i_mid, i_cur, i_prev) & TED Stage 1 sample REGISTERED
    % curr_strobe_d (st_old.out_valid) & mid_strobe_d (st_old.mid_d) on ce_str.
    if st_old.mid_d
        st.mid_i(:) = R(st_old.y_i);
        st.mid_q(:) = R(st_old.y_q);
    end

    if st_old.out_valid
        st.prev_i(:) = R(st_old.cur_i);
        st.prev_q(:) = R(st_old.cur_q);
        st.cur_i(:)  = R(st_old.y_i);
        st.cur_q(:)  = R(st_old.y_q);

        d_i = T.fi(R(st_old.y_i) - R(st_old.cur_i), 'ted_d');
        d_q = T.fi(R(st_old.y_q) - R(st_old.cur_q), 'ted_d');
        e_calc = T.fi(R(st_old.mid_i) * R(d_i) + R(st_old.mid_q) * R(d_q), 'ted_e');
    else
        e_calc = T.fi(0, 'ted_e');
    end

    % TED 2-Stage Pipeline (Stage 1: v_stg1_q; Stage 2: error_valid_o / error_o)
    st.pipe_ted_val = [st_old.out_valid, st_old.pipe_ted_val(1)];
    st.pipe_ted_e   = [e_calc,           R(st_old.pipe_ted_e(1))];

    st.te_val = st_old.pipe_ted_val(1);
    if st_old.pipe_ted_val(1)
        st.te_e(:) = R(st_old.pipe_ted_e(1));
    end

    % pI_loop 2-Stage Pipeline (.valid_i = ted_error_valid && ce_str)
    st.pipe_pi_val = [st_old.te_val, false];
    st.pipe_pi_e   = st_old.te_e;

    if st_old.pipe_pi_val(1)
        [v_pi, acc_new, sat_f] = str_pi_filter(st_old.pipe_pi_e, st_old.acc, T.str.kp, T.str.ki, T.str.max_pi, T);
        st.acc(:)    = acc_new;
        st.pi_reg(:) = R(v_pi);
        q25_s        = R(T.fi(T.c.q25, 'M_s'));
        st.W(:)      = T.fi(q25_s + R(v_pi), 'M');
        if sat_f
            st.sat_cnt(:) = R(st_old.sat_cnt) + 1;
        end
    end

    % Continuous Hardware Lock Detector (3-stage pipeline inside str_lock_hw_step)
    st.lock          = str_lock_hw_step(st_old.lock, st_old.te_val, st_old.te_e, double(st.sym_cnt), T);
    st.lock.locked_q = st.lock.locked;

    out = str_drive_outputs(st, in, T);
end

% =========================================================================
% LOCAL HELPER FUNCTIONS
% =========================================================================
function out = str_drive_outputs(st, in, T)
    out.m_axis_valid_o  = st.out_valid;
    out.m_axis_i_sym_o  = st.y_i;
    out.m_axis_q_sym_o  = st.y_q;
    out.lock_o          = st.lock.locked;
    out.ted_err_valid_o = st.te_val;
    out.ted_err_o       = st.te_e;
    out.mu_o            = st.mu_reg;
    if isfield(in, 'force_w_en_i') && logical(in.force_w_en_i)
        out.w_o = T.fi(in.force_w_i, 'M');
    else
        out.w_o = st.W;
    end
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

function ld = str_lock_hw_step(ld_old, valid_i, e_in, sym_idx, T)
    ld = ld_old;

    % Stage 1: Absolute error calculation (|e|)
    if valid_i
        e_val = double(bitsra(int64(storedInteger(e_in)), 3));
        if e_val < 0
            e_abs = -e_val;
        else
            e_abs = e_val;
        end
        ld.e_abs_r = mod(e_abs, 2^23);
    end

    % Clock-rate pipeline progression
    ld.v1 = valid_i;
    ld.v2 = ld_old.v1;

    % Stage 2: EMA update (on v1)
    if ld_old.v1
        shift_val = floor(double(ld_old.m_acc) / 16);
        m_next = double(ld_old.m_acc) + double(ld_old.e_abs_r) - shift_val;
        m_next = max(0, min(m_next, 2^27 - 1));
        ld.m_acc = uint32(m_next);
        ld.m_val_r = uint32(floor(m_next / 16));
        if ld_old.sym_cnt < 1
            ld.sym_cnt = ld_old.sym_cnt + 1;
        end
    end

    % Stage 3: Hysteresis comparison and leaky bucket (on v2)
    if ld_old.v2
        if ld_old.locked
            thr = 127346; % LOCK_THR_EXIT
        else
            thr = 50938;  % LOCK_THR_ENTER
        end

        idx_ok = (ld_old.sym_cnt >= 0);
        good = (double(ld_old.m_val_r) < thr) && idx_ok;

        b_old = ld_old.bucket;
        if good
            b_new = min(b_old + 1, 20);
        elseif b_old >= 2
            b_new = b_old - 2;
        else
            b_new = 0;
        end
        ld.bucket = b_new;

        if b_new >= 20
            if ~ld_old.locked && isnan(ld_old.lock_sym)
                ld.lock_sym = sym_idx;
            end
            ld.locked = true;
        elseif b_new == 0
            ld.locked = false;
        end
    end
end
