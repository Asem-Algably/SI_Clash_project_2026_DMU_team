function str_out = run_str_subsystem(rx_samples, cfg, in_scale)
    % RUN_STR_SUBSYSTEM  Standalone simulation model for Symbol Timing Recovery (str.md).
    %
    % Pipeline Behavior:
    %   - Continuously runs on incoming samples, independently of burst FSM states.
    %   - Modulo-1 counter decrements every sample by W (nominal 0.25 + loop filter correction v_pi).
    %   - 4-sample shift register feeds piecewise-parabolic Farrow interpolator.
    %   - Mid and current strobes trigger half-symbol and on-time symbol interpolation.
    %   - Non-data-aided Gardner TED drives 2nd-order saturating PI filter.
    %
    % Inputs:
    %   rx_samples - Vector of oversampled baseband I/Q samples (4 samples per symbol)
    %   cfg        - Master system configuration struct
    %   in_scale   - Front-end scaling factor (default 1.0)
    %
    % Outputs:
    %   str_out - Diagnostic struct with interpolated symbols, timing phase, and lock metrics

    if exist('in_scale', 'var') == 0
        in_scale = 1.0;
    end
    rx_samples = rx_samples(:);
    N_samp     = numel(rx_samples);

    if isfield(cfg, 'norm_mode') && strcmpi(cfg.norm_mode, 'rms')
        K_pre_ref  = 6.4772;
        K_qpsk_ref = 1.0771;
        K_16_ref   = 1.1093;
    else
        K_pre_ref  = 12.9543;
        K_qpsk_ref = 2.1541;
        K_16_ref   = 1.2326;
    end

    % Gardner TED is quadratic in input amplitude: e_ted scales with in_scale^2.
    scale_sq = in_scale^2;
    K_pre_sc = K_pre_ref * scale_sq;
    if cfg.mod_type == 0
        K_nom_sc = K_qpsk_ref * scale_sq;
    else
        K_nom_sc = K_16_ref   * scale_sq;
    end

    % Compute single fixed Kp, Ki (internal fixed parameters)
    [Kp_fixed, Ki_fixed] = compute_loop_gains(cfg.str.Bn_Ts, cfg.str.zeta, K_nom_sc, cfg.str.K_nco, 0, false);

    max_v_pi = 0.035;
    if isfield(cfg.str, 'max_v_pi')
        max_v_pi = cfg.str.max_v_pi;
    end

    buf4       = zeros(4, 1);
    M          = 0.75;     % reset value (str.md Section 2)
    W          = cfg.str.W_nom;
    int_state  = 0.0;
    y_prev     = 0.0;
    y_mid_hold = 0.0;
    lock_state = init_lock_state(cfg.lock.str_m0);

    max_syms    = max(ceil(N_samp / cfg.sps), 10);
    sym_out     = zeros(max_syms, 1);
    mu_log      = zeros(max_syms, 1);
    t_phase_log = zeros(max_syms, 1);
    ted_log     = zeros(max_syms, 1);
    W_log       = zeros(max_syms, 1);
    lock_log    = false(max_syms, 1);
    sym_clk_idx = zeros(max_syms, 1);
    lock_m_log  = zeros(max_syms, 1);
    v_log       = zeros(max_syms, 1);
    sym_cnt     = 0;
    sat_count   = 0;

    for n = 1:N_samp
        buf4 = [buf4(2:4); rx_samples(n)];
        [M_next, strobe, mu, mid_strobe, mu_mid] = modulo1_controller(M, W, cfg.str.mu_bits, cfg.str.mu_mode, cfg.str.W_nom);

        if mid_strobe
            y_mid_hold = farrow_interpolator(buf4, mu_mid);
        end

        if strobe
            sym_cnt = sym_cnt + 1;
            y_cur   = farrow_interpolator(buf4, mu);
            e_ted   = gardner_ted(y_cur, y_prev, y_mid_hold);

            [v_pi, int_state, sat_flag] = pi_loop_filter(e_ted, int_state, Kp_fixed, Ki_fixed, max_v_pi);
            if sat_flag
                sat_count = sat_count + 1;
            end

            if isfield(cfg.str, 'open_loop') && cfg.str.open_loop
                W = cfg.str.W_nom;
            else
                W = cfg.str.W_nom + v_pi;
            end
            y_prev = y_cur;

            % Hardware-compliant continuous lock detector (str.md Section 3, no freeze)
            lock_state = dynamic_lock_detector(e_ted / K_pre_sc, lock_state, ...
                cfg.lock.ema_shift, cfg.lock.str_thr_enter, cfg.lock.str_thr_exit, cfg.lock.str_confirm_cnt, sym_cnt);
            lock_m_log(sym_cnt) = lock_state.m;

            sym_out(sym_cnt)     = y_cur;
            mu_log(sym_cnt)      = mu;
            t_phase_log(sym_cnt) = ((n - 3) + mu) / cfg.sps - (sym_cnt - 1);
            ted_log(sym_cnt)     = e_ted;
            W_log(sym_cnt)       = W;
            v_log(sym_cnt)       = v_pi;
            lock_log(sym_cnt)    = lock_state.locked;
            sym_clk_idx(sym_cnt) = n;
        end
        M = M_next;
    end

    str_out.symbols     = sym_out(1:sym_cnt);
    str_out.mu_log      = mu_log(1:sym_cnt);
    str_out.t_phase_log = t_phase_log(1:sym_cnt);
    str_out.ted_log     = ted_log(1:sym_cnt);
    str_out.W_log       = W_log(1:sym_cnt);
    str_out.lock_log    = lock_log(1:sym_cnt);
    str_out.sym_clk_idx = sym_clk_idx(1:sym_cnt);
    str_out.lock_sym    = lock_state.lock_sym;
    str_out.lock_m_log  = lock_m_log(1:sym_cnt);
    str_out.v_pi_log    = v_log(1:sym_cnt);
    str_out.sat_count   = sat_count;
end
