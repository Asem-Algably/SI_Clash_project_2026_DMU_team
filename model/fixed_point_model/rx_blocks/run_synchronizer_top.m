function rx_out = run_synchronizer_top(in_sample_iq, in_sample_valid, cfg, ref_preamble)
    % Blind Three-Stage Synchronizer Top Level
    % Supports:
    %   - cfg.exec_mode = 'fixed_cycle'  (Cycle-accurate, interface-accurate Fixed-Point Designer model)
    %   - cfg.exec_mode = 'float_cycle'  (Cycle-accurate, interface-accurate double-precision model)
    %   - cfg.exec_mode = 'float_symbol' (Fast symbol-rate floating-point model)

    if nargin < 3 || isempty(cfg), cfg = get_default_config(); end
    if nargin < 4, ref_preamble = []; end %#ok<NASGU>

    if isfield(cfg, 'exec_mode') && (strcmpi(cfg.exec_mode, 'fixed_cycle') || strcmpi(cfg.exec_mode, 'float_cycle'))
        [rx_out, ~, T_fxp] = run_cycle_accurate_top(in_sample_iq, in_sample_valid, cfg);
        % Export hardware parameters to config folder upon completion
        export_hardware_parameters(T_fxp);
        return;
    end

    in_sample_iq    = in_sample_iq(:);
    in_sample_valid = logical(in_sample_valid(:));

    % =====================================================================
    % 0. WRAPPER INPUT RIGHT-SHIFT (>> 1 = / 2, +1 MSB Pad) & Q1.11 QUANTIZATION
    % =====================================================================
    use_shift = ~isfield(cfg, 'wrapper_shift_en') || cfg.wrapper_shift_en;
    in_scale  = 1.0;
    if use_shift
        if isfield(cfg, 'in_scale') && ~isempty(cfg.in_scale)
            in_scale = cfg.in_scale;
        else
            in_scale = 0.5;
        end
    end

    rx_in_scaled = in_sample_iq(in_sample_valid) * in_scale;

    do_q11 = isfield(cfg, 'quantize_q11') && cfg.quantize_q11;
    if do_q11
        scale_q11 = 2048; % 2^11 for signed Q1.11 in [-1, 1 - 2^-11]
        q11_min   = -1.0;
        q11_max   = 1.0 - (1.0 / scale_q11);
        re_in     = round(real(rx_in_scaled) * scale_q11) / scale_q11;
        im_in     = round(imag(rx_in_scaled) * scale_q11) / scale_q11;
        q11_clips = sum((re_in < q11_min) | (re_in > q11_max)) + sum((im_in < q11_min) | (im_in > q11_max));
        rx_in_scaled = min(max(re_in, q11_min), q11_max) + 1j * min(max(im_in, q11_min), q11_max);
    else
        q11_clips = 0;
    end

    % =====================================================================
    % 1. RUN SYMBOL TIMING RECOVERY (STR)
    % =====================================================================
    str_res = run_str_subsystem(rx_in_scaled, cfg, in_scale);
    N_sym   = numel(str_res.symbols);

    % =====================================================================
    % 2. COSTAS LOOP GAINS (Single Fixed Gain, No Post-Lock Switching)
    % =====================================================================
    norm_mode = 'peak';
    if isfield(cfg, 'norm_mode') && ~isempty(cfg.norm_mode)
        norm_mode = cfg.norm_mode;
    end
    c_pay = get_constellation_map(cfg.mod_type, norm_mode);

    pipe_delay = 0;
    if isfield(cfg.costas, 'pipe_delay')
        pipe_delay = max(round(cfg.costas.pipe_delay), 0);
    end
    comp_delay = isfield(cfg.costas, 'compensate_delay') && cfg.costas.compensate_delay;
    K_nco      = 2 * pi;

    es_pay_sc  = c_pay.avg_power * (in_scale^2);

    % Use a single fixed gain across the entire burst (no preamble vs payload gain switching)
    [Kp_c, Ki_c] = decode_gain_ports(0, cfg.costas.Bn_Ts, cfg.costas.zeta, ...
        cfg.costas.Kp_ted * es_pay_sc, K_nco, pipe_delay, comp_delay);

    max_v_pi_c = 0.12;
    if isfield(cfg.costas, 'max_v_pi') && ~isempty(cfg.costas.max_v_pi)
        max_v_pi_c = cfg.costas.max_v_pi;
    end

    err_fifo = zeros(max(pipe_delay, 1), 1);

    N_A = 160; N_B = 80; N_C = 48;
    if isfield(cfg, 'preamble')
        N_A = cfg.preamble.N_A;
        N_B = cfg.preamble.N_B;
        N_C = cfg.preamble.N_C;
    end
    N_AB       = N_A + N_B;
    N_preamble = cfg.N_preamble;

    quad_enable = ~isfield(cfg, 'quad') || ~isfield(cfg.quad, 'enable') || cfg.quad.enable;
    use_qpsk_pre_slicer = ~isfield(cfg.costas, 'preamble_slicer') || strcmpi(cfg.costas.preamble_slicer, 'qpsk');

    fixed_start_sym = 0;
    if isfield(cfg.coarse, 'fixed_start_sym')
        fixed_start_sym = cfg.coarse.fixed_start_sym;
    end

    fsm.state           = 'WAIT_BURST';
    fsm.state_timer     = 0;
    fsm.sym_cnt         = 0;
    fsm.coarse_win_len  = cfg.coarse.win_len;
    fsm.fixed_start_sym = fixed_start_sym;

    coarse_buf          = zeros(cfg.coarse.win_len, 1);
    coarse_cfo_est      = 0.0;
    nco_phase           = 0.0;
    nco_freq            = 0.0;
    costas_int          = 0.0;
    load_sym_idx        = NaN;
    coarse_done_sym     = NaN;
    costas_settle_sym   = NaN;
    costas_sat_count    = 0;

    acq_lock_state      = init_lock_state(cfg.lock.costas_m0);
    pub_lock_state      = init_lock_state(cfg.lock.costas_m0);

    cnt_I               = 0;
    cnt_Q               = 0;
    quad_done           = false;
    quad_unresolved     = false;
    quad_q              = NaN;
    quad_k              = NaN;
    quad_corr_sym       = NaN;
    nco_phase_pre_quad  = NaN;

    out_sym_internal    = zeros(N_sym, 1);
    slicer_sym          = zeros(N_sym, 1);
    costas_err          = zeros(N_sym, 1);
    nco_freq_log        = zeros(N_sym, 1);
    nco_phase_log       = zeros(N_sym, 1);
    costas_lock         = false(N_sym, 1);
    costas_settled_log  = false(N_sym, 1);
    lock_detect         = false(N_sym, 1);
    fsm_state_log       = strings(N_sym, 1);

    sym_bus_lim = 2.0 * in_scale;

    for k = 1:N_sym
        fsm.sym_cnt = k;
        str_sym_k   = str_res.symbols(k);
        str_lock_k  = str_res.lock_log(k);

        derot_raw = derotator(str_sym_k, nco_phase, cfg.costas.derot_mode, cfg.costas.lut_addr_bits);
        derot_k   = min(max(real(derot_raw), -sym_bus_lim), sym_bus_lim) + ...
                    1j * min(max(imag(derot_raw), -sym_bus_lim), sym_bus_lim);

        [fsm, costas_mode, preamble_end_pulse] = burst_fsm(fsm, true, str_lock_k, N_AB, N_preamble);

        coarse_valid_pulse = false;
        if strcmp(fsm.state, 'COARSE_EST')
            idx_w = min(max(round(fsm.state_timer), 1), cfg.coarse.win_len);
            if strcmpi(cfg.coarse.tap_point, 'derotator')
                coarse_buf(idx_w) = derot_k;
            else
                coarse_buf(idx_w) = str_sym_k;
            end
        elseif strcmp(fsm.state, 'LOAD')
            [best_cfo, ~]      = run_coarse_cfo_subsystem(coarse_buf, cfg, []);
            coarse_valid_pulse = true;
            load_sym_idx       = k;
            coarse_done_sym    = k;
            err_fifo(:)        = 0.0;
        end

        is_pre     = (k <= N_preamble);
        slicer_mod = cfg.mod_type;
        if use_qpsk_pre_slicer && is_pre
            slicer_mod = 0;
        end

        a_ref_unscaled = qam_slicer(derot_k / in_scale, slicer_mod, norm_mode);
        a_ref          = a_ref_unscaled * in_scale;

        phase_adj_valid = false;
        phase_adj_rad   = 0.0;

        if strcmp(costas_mode, 'HOLD')
            e_raw = 0.0;
            v_pi  = 0.0;
            cnt_I = 0;
            cnt_Q = 0;
            [nco_phase_next, nco_freq] = nco_32bit(nco_phase, coarse_cfo_est, 0.0, true);
        else
            e_raw = costas_phase_detector(derot_k, a_ref);

            if pipe_delay > 0
                e_loop   = err_fifo(1);
                err_fifo = [err_fifo(2:end); e_raw];
            else
                e_loop   = e_raw;
            end

            % Use single fixed Kp_c and Ki_c throughout entire burst
            [v_pi, costas_int, sat_c] = pi_loop_filter(e_loop, costas_int, Kp_c, Ki_c, max_v_pi_c);
            if sat_c
                costas_sat_count = costas_sat_count + 1;
            end

            e_norm = e_raw / es_pay_sc;

            sym_since_load = k - load_sym_idx;
            acq_lock_state = dynamic_lock_detector(e_norm, acq_lock_state, ...
                cfg.lock.ema_shift, cfg.lock.costas_thr_enter, cfg.lock.costas_thr_exit, cfg.lock.costas_confirm_cnt, sym_since_load);
            if acq_lock_state.locked && isnan(costas_settle_sym)
                costas_settle_sym = k;
            end

            if ~quad_done
                if ~acq_lock_state.locked
                    cnt_I = 0;
                    cnt_Q = 0;
                else
                    step_I = 1; if real(a_ref) < 0, step_I = -1; end
                    step_Q = 1; if imag(a_ref) < 0, step_Q = -1; end
                    cnt_I  = min(max(cnt_I + step_I, -16), 15);
                    cnt_Q  = min(max(cnt_Q + step_Q, -16), 15);
                end

                counter_full = ((cnt_I == 15) || (cnt_I == -16) || (cnt_Q == 15) || (cnt_Q == -16)) && (cnt_I ~= 0) && (cnt_Q ~= 0);
                if counter_full || preamble_end_pulse
                    nco_phase_pre_quad = nco_phase;
                    if (cnt_I == 0) || (cnt_Q == 0)
                        quad_unresolved = true;
                        quad_q          = NaN;
                        quad_k          = NaN;
                    else
                        if cnt_I > 0 && cnt_Q > 0
                            quad_q = 1;
                        elseif cnt_I < 0 && cnt_Q > 0
                            quad_q = 2;
                        elseif cnt_I < 0 && cnt_Q < 0
                            quad_q = 3;
                        else
                            quad_q = 4;
                        end
                        quad_k          = mod(quad_q - 1, 4);
                        quad_unresolved = false;
                        if quad_enable
                            phase_adj_valid = true;
                            phase_adj_rad   = quad_k * (pi / 2);
                        end
                    end
                    quad_corr_sym  = k;
                    quad_done      = true;
                    pub_lock_state = init_lock_state(cfg.lock.costas_m0);
                end
            else
                if ~quad_unresolved
                    pub_lock_state = dynamic_lock_detector(e_norm, pub_lock_state, ...
                        cfg.lock.ema_shift, cfg.lock.costas_thr_enter, cfg.lock.costas_thr_exit, cfg.lock.costas_confirm_cnt, k - quad_corr_sym);
                end
            end

            [nco_phase_next, nco_freq] = nco_32bit(nco_phase, coarse_cfo_est, v_pi, false);
            if phase_adj_valid
                nco_phase_next = mod(nco_phase_next + phase_adj_rad + pi, 2 * pi) - pi;
            end
        end

        if coarse_valid_pulse
            if strcmpi(cfg.coarse.tap_point, 'derotator')
                coarse_cfo_est = coarse_cfo_est + best_cfo;
            else
                coarse_cfo_est = best_cfo;
            end
        end

        pub_costas_locked = quad_done && (~quad_unresolved) && pub_lock_state.locked;
        sys_locked        = str_lock_k && pub_costas_locked;

        out_sym_internal(k)   = derot_k;
        slicer_sym(k)         = a_ref_unscaled;
        costas_err(k)         = e_raw;
        nco_freq_log(k)       = nco_freq;
        nco_phase_log(k)      = nco_phase;
        costas_lock(k)        = pub_costas_locked;
        costas_settled_log(k) = acq_lock_state.locked;
        lock_detect(k)        = sys_locked;
        fsm_state_log(k)      = string(fsm.state);
        nco_phase             = nco_phase_next;
    end

    do_q15 = isfield(cfg, 'quantize_q15') && cfg.quantize_q15;
    if do_q15
        scale_q15 = 32768;
        q_min     = -1.0;
        q_max     = 1.0 - (1.0 / scale_q15);
        re_q      = round(real(out_sym_internal) * scale_q15) / scale_q15;
        im_q      = round(imag(out_sym_internal) * scale_q15) / scale_q15;
        q15_clips = sum((re_q < q_min) | (re_q > q_max)) + sum((im_q < q_min) | (im_q > q_max));
        out_q15   = min(max(re_q, q_min), q_max) + 1j * min(max(im_q, q_min), q_max);
    else
        out_q15   = out_sym_internal;
        q15_clips = 0;
    end

    out_display     = out_q15 / in_scale;
    str_res.symbols = str_res.symbols / in_scale;

    first_pub_lock = find(costas_lock, 1, 'first');
    if isempty(first_pub_lock)
        pub_lock_from_start = NaN;
        pub_lock_from_load  = NaN;
    else
        pub_lock_from_start = first_pub_lock;
        pub_lock_from_load  = first_pub_lock - load_sym_idx;
    end

    rx_out.out_sym_i               = real(out_display);
    rx_out.out_sym_q               = imag(out_display);
    rx_out.out_sym_cplx            = out_display;
    rx_out.q11_clip_count          = q11_clips;
    rx_out.q15_clip_count          = q15_clips;
    rx_out.slicer_sym              = slicer_sym;
    rx_out.out_sym_valid           = true(N_sym, 1);
    rx_out.coarse_cfo_est          = coarse_cfo_est;
    rx_out.fine_cfo_est            = coarse_cfo_est + costas_int;
    rx_out.lock_detect             = lock_detect;
    rx_out.str                     = str_res;
    rx_out.costas_err              = costas_err;
    rx_out.nco_freq_log            = nco_freq_log;
    rx_out.nco_phase_log           = nco_phase_log;
    rx_out.costas_lock             = costas_lock;
    rx_out.costas_settled_log      = costas_settled_log;
    rx_out.fsm_state_log           = fsm_state_log;
    rx_out.str_lock_sym            = str_res.lock_sym;
    rx_out.coarse_done_sym         = coarse_done_sym;
    rx_out.load_sym_idx            = load_sym_idx;
    rx_out.costas_settle_sym       = costas_settle_sym;
    rx_out.costas_lock_sym         = pub_lock_from_start;
    rx_out.costas_lock_from_load   = pub_lock_from_load;
    rx_out.quad_counts             = [cnt_I, cnt_Q];
    rx_out.quad_m                  = quad_q;
    rx_out.quad_k                  = quad_k;
    rx_out.quad_unresolved         = quad_unresolved;
    rx_out.quad_corr_sym           = quad_corr_sym;
    rx_out.nco_phase_pre_quad      = nco_phase_pre_quad;
    rx_out.str_sat_count           = str_res.sat_count;
    rx_out.costas_sat_count        = costas_sat_count;
end
