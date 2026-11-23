function str_out = run_str_subsystem(rx_samples_q11, cfg)
    % Part 0c, 0d, 4a, 4b: STR subsystem with input_headroom restoration,
    % norm_mode-aware Gardner TED gain scheduling, anti-windup, and saturation counter.
    headroom = 0.22;
    if isfield(cfg, 'input_headroom') && ~isempty(cfg.input_headroom)
        headroom = cfg.input_headroom;
    end
    rx_samples = rx_samples_q11(:) / headroom;
    N_samp     = numel(rx_samples);

    if isfield(cfg, 'norm_mode') && strcmpi(cfg.norm_mode, 'rms')
        K_pre_default  = 6.4772;
        K_qpsk_default = 1.0771;
        K_16_default   = 1.1093;
    else
        K_pre_default  = 12.9543;
        K_qpsk_default = 2.1541;
        K_16_default   = 1.2326;
    end

    [Kp_def, Ki_def] = compute_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, cfg.str.Kp_ted, cfg.str.K_nco);
    gain_sched = isfield(cfg.str, 'gain_sched') && cfg.str.gain_sched;
    if gain_sched
        K_pre = K_pre_default;
        if cfg.mod_type == 0
            K_pay = K_qpsk_default;
        else
            K_pay = K_16_default;
        end
        [Kp_pre, Ki_pre] = compute_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, K_pre, cfg.str.K_nco);
        [Kp_pay, Ki_pay] = compute_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, K_pay, cfg.str.K_nco);
    end

    max_v_pi = 0.035;
    if isfield(cfg.str, 'max_v_pi') && ~isempty(cfg.str.max_v_pi)
        max_v_pi = cfg.str.max_v_pi;
    end

    buf4       = zeros(4, 1);
    eta        = 0.75;
    W          = cfg.str.W_nom;
    int_state  = 0.0;
    y_prev     = 0.0;
    y_mid_hold = 0.0;
    lock_state = struct('ema_var', 0.2, 'bucket', 0, 'locked', false, 'lock_sym', NaN);

    max_syms    = max(ceil(N_samp / 2), 10);
    sym_out     = zeros(max_syms, 1);
    mu_log      = zeros(max_syms, 1);
    t_phase_log = zeros(max_syms, 1);
    ted_log     = zeros(max_syms, 1);
    W_log       = zeros(max_syms, 1);
    lock_log    = false(max_syms, 1);
    sym_clk_idx = zeros(max_syms, 1);
    sym_cnt     = 0;
    sat_count   = 0;

    for n = 1:N_samp
        buf4 = [buf4(2:4); rx_samples(n)];
        [eta_next, strobe, mu, mid_strobe, mu_mid] = modulo1_controller(eta, W, cfg.str.mu_bits);

        if mid_strobe
            y_mid_hold = farrow_interpolator(buf4, mu_mid, cfg);
        end

        if strobe
            sym_cnt = sym_cnt + 1;
            y_cur   = farrow_interpolator(buf4, mu, cfg);
            e_ted   = gardner_ted(y_cur, y_prev, y_mid_hold);

            if gain_sched
                if sym_cnt <= cfg.N_preamble
                    Kp_use = Kp_pre; Ki_use = Ki_pre;
                else
                    Kp_use = Kp_pay; Ki_use = Ki_pay;
                end
            else
                Kp_use = Kp_def; Ki_use = Ki_def;
            end

            [v_pi, int_state, sat_flag] = pi_loop_filter(e_ted, int_state, Kp_use, Ki_use, max_v_pi);
            if sat_flag
                sat_count = sat_count + 1;
            end

            if isfield(cfg.str, 'open_loop') && cfg.str.open_loop
                W = cfg.str.W_nom;
            else
                W = cfg.str.W_nom + v_pi;
            end
            y_prev = y_cur;

            lock_state = dynamic_lock_detector(v_pi * 80, lock_state, ...
                cfg.lock.str_ema_alpha, cfg.lock.str_var_thresh, cfg.lock.str_confirm_cnt, sym_cnt);

            sym_out(sym_cnt)     = y_cur;
            mu_log(sym_cnt)      = mu;
            t_phase_log(sym_cnt) = ((n - 3) + mu) / cfg.sps - (sym_cnt - 1);
            ted_log(sym_cnt)     = e_ted;
            W_log(sym_cnt)       = W;
            lock_log(sym_cnt)    = lock_state.locked;
            sym_clk_idx(sym_cnt) = n;
        end
        eta = eta_next;
    end

    str_out.symbols     = sym_out(1:sym_cnt);
    str_out.mu_log      = mu_log(1:sym_cnt);
    str_out.t_phase_log = t_phase_log(1:sym_cnt);
    str_out.ted_log     = ted_log(1:sym_cnt);
    str_out.W_log       = W_log(1:sym_cnt);
    str_out.lock_log    = lock_log(1:sym_cnt);
    str_out.sym_clk_idx = sym_clk_idx(1:sym_cnt);
    str_out.lock_sym    = lock_state.lock_sym;
    str_out.sat_count   = sat_count;
end
