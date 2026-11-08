function rx_out = run_synchronizer_top(in_sample_iq, in_sample_valid, cfg, ref_preamble)
    % Blind Three-Stage Synchronizer Top Level (Parts 0, 1, 2, 3, 4; No DFT)
    if nargin < 4, ref_preamble = []; end %#ok<NASGU>
    in_sample_iq    = in_sample_iq(:);
    in_sample_valid = logical(in_sample_valid(:));

    % 1. Run Symbol Timing Recovery (STR)
    str_res = run_str_subsystem(in_sample_iq(in_sample_valid), cfg);
    N_sym   = numel(str_res.symbols);

    % 2. Compute Costas PI Loop Gains Scaled by Constellation Es (Part 0a/0b)
    norm_mode = 'peak';
    if isfield(cfg, 'norm_mode') && ~isempty(cfg.norm_mode)
        norm_mode = cfg.norm_mode;
    end
    c_qpsk = get_constellation_map(0, norm_mode);
    c_pay  = get_constellation_map(cfg.mod_type, norm_mode);

    pipe_delay = 0;
    if isfield(cfg.costas, 'pipe_delay')
        pipe_delay = max(round(cfg.costas.pipe_delay), 0);
    end
    comp_delay = isfield(cfg.costas, 'compensate_delay') && cfg.costas.compensate_delay;
    K_nco      = 2 * pi;

    [Kp_c_pre, Ki_c_pre] = compute_loop_gains(cfg.costas.Bn_Ts, cfg.costas.zeta, c_qpsk.avg_power, K_nco, pipe_delay, comp_delay);
    [Kp_c_pay, Ki_c_pay] = compute_loop_gains(cfg.costas.Bn_Ts, cfg.costas.zeta, c_pay.avg_power,  K_nco, pipe_delay, comp_delay);

    max_v_pi_c = 0.12;
    if isfield(cfg.costas, 'max_v_pi') && ~isempty(cfg.costas.max_v_pi)
        max_v_pi_c = cfg.costas.max_v_pi;
    end

    err_fifo = zeros(max(pipe_delay, 1), 1);

    N_A = 208; N_B = 60; N_C = 48;
    if isfield(cfg, 'preamble')
        N_A = cfg.preamble.N_A;
        N_B = cfg.preamble.N_B;
        N_C = cfg.preamble.N_C;
    end
    N_AB       = N_A + N_B;
    N_preamble = cfg.N_preamble;

    quad_enable    = true;
    quad_skip      = 4;
    quad_min_ratio = 0.25;
    if isfield(cfg, 'quad')
        if isfield(cfg.quad, 'enable'),    quad_enable    = cfg.quad.enable;    end
        if isfield(cfg.quad, 'skip'),      quad_skip      = cfg.quad.skip;      end
        if isfield(cfg.quad, 'min_ratio'), quad_min_ratio = cfg.quad.min_ratio; end
    end

    use_qpsk_pre_slicer = true;
    if isfield(cfg.costas, 'preamble_slicer')
        use_qpsk_pre_slicer = strcmpi(cfg.costas.preamble_slicer, 'qpsk');
    end

    fixed_start_sym = 0;
    if isfield(cfg.coarse, 'fixed_start_sym')
        fixed_start_sym = cfg.coarse.fixed_start_sym;
    end

    fsm.state           = 'WAIT_BURST';
    fsm.state_timer     = 0;
    fsm.sym_cnt         = 0;
    fsm.coarse_win_len  = cfg.coarse.win_len;
    fsm.fixed_start_sym = fixed_start_sym;
    fsm.quad_unresolved = false;

    coarse_buf          = zeros(cfg.coarse.win_len, 1);
    coarse_cfo_est      = 0.0;
    nco_phase           = 0.0;
    nco_freq            = 0.0;
    costas_int          = 0.0;
    load_sym_idx        = NaN;
    coarse_done_sym     = NaN;
    costas_settle_sym   = NaN;
    costas_sat_count    = 0;

    % Part 3d: Real lock check (ema_var initialized at 0.1, NOT at threshold)
    acq_lock_state      = struct('ema_var', 0.1, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
    pub_lock_state      = struct('ema_var', 0.1, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
    quad_done           = false;

    quad_counts         = zeros(1, 4);
    quad_m              = NaN;
    quad_k              = NaN;
    quad_unresolved     = false;
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

    for k = 1:N_sym
        fsm.sym_cnt = k;
        str_sym_k   = str_res.symbols(k);
        str_lock_k  = str_res.lock_log(k);

        derot_k = derotator(str_sym_k, nco_phase, cfg.costas.derot_mode);

        prev_state = fsm.state;
        [fsm, costas_mode] = burst_fsm(fsm, true, str_lock_k, acq_lock_state.locked, N_AB, N_preamble);

        if strcmp(fsm.state, 'COARSE_EST')
            idx_w = min(max(round(fsm.state_timer), 1), cfg.coarse.win_len);
            if strcmpi(cfg.coarse.tap_point, 'derotator')
                coarse_buf(idx_w) = derot_k;
            else
                coarse_buf(idx_w) = str_sym_k;
            end
        elseif strcmp(fsm.state, 'LOAD')
            [best_cfo, ~] = run_coarse_cfo_subsystem(coarse_buf, cfg, []);
            if strcmpi(cfg.coarse.tap_point, 'derotator')
                coarse_cfo_est = coarse_cfo_est + best_cfo;
            else
                coarse_cfo_est = best_cfo;
            end
            load_sym_idx    = k;
            coarse_done_sym = k;
            err_fifo(:)     = 0.0;
        end

        if strcmp(prev_state, 'COSTAS_ACQ') && strcmp(fsm.state, 'TRACK') && fsm.quad_unresolved
            quad_unresolved = true;
            quad_m          = NaN;
            quad_k          = NaN;
            quad_corr_sym   = k;
            quad_done       = true;
            pub_lock_state  = struct('ema_var', 0.1, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
        end

        if strcmp(fsm.state, 'QUAD_CHECK') || (strcmp(prev_state, 'QUAD_CHECK') && k == N_preamble)
            if k >= (N_AB + 1 + quad_skip) && k <= N_preamble
                I_s = real(derot_k);
                Q_s = imag(derot_k);
                if I_s >= 0 && Q_s >= 0
                    q_idx = 1; % Q1
                elseif I_s < 0 && Q_s >= 0
                    q_idx = 2; % Q2
                elseif I_s < 0 && Q_s < 0
                    q_idx = 3; % Q3
                else
                    q_idx = 4; % Q4
                end
                quad_counts(q_idx) = quad_counts(q_idx) + 1;
            end
        end

        if strcmp(costas_mode, 'HOLD')
            a_ref  = qam_slicer(derot_k, 0, norm_mode);
            e_raw  = 0.0;
            [nco_phase_next, nco_freq] = nco_32bit(nco_phase, coarse_cfo_est, 0.0, true);
        else
            is_pre     = (k <= N_preamble);
            slicer_mod = cfg.mod_type;
            if use_qpsk_pre_slicer && is_pre
                slicer_mod = 0;
            end
            a_ref = qam_slicer(derot_k, slicer_mod, norm_mode);
            e_raw = costas_phase_detector(derot_k, a_ref);

            if pipe_delay > 0
                e_loop   = err_fifo(1);
                err_fifo = [err_fifo(2:end); e_raw];
            else
                e_loop   = e_raw;
            end

            if is_pre
                Kp_use = Kp_c_pre; Ki_use = Ki_c_pre; es_cur = c_qpsk.avg_power;
            else
                Kp_use = Kp_c_pay; Ki_use = Ki_c_pay; es_cur = c_pay.avg_power;
            end

            [v_pi, costas_int, sat_c] = pi_loop_filter(e_loop, costas_int, Kp_use, Ki_use, max_v_pi_c);
            if sat_c
                costas_sat_count = costas_sat_count + 1;
            end

            [nco_phase_next, nco_freq] = nco_32bit(nco_phase, coarse_cfo_est, v_pi, false);

            e_norm = e_raw / es_cur;
            if ~quad_done
                sym_since_load = k - load_sym_idx;
                acq_lock_state = dynamic_lock_detector(e_norm, acq_lock_state, ...
                    cfg.lock.costas_ema_alpha, cfg.lock.costas_var_thresh, cfg.lock.costas_confirm_cnt, sym_since_load);
                if acq_lock_state.locked && isnan(costas_settle_sym)
                    costas_settle_sym = k;
                end
            else
                if ~quad_unresolved
                    pub_lock_state = dynamic_lock_detector(e_norm, pub_lock_state, ...
                        cfg.lock.costas_ema_alpha, cfg.lock.costas_var_thresh, cfg.lock.costas_confirm_cnt, k - quad_corr_sym);
                end
            end
        end

        if ~quad_done && (strcmp(prev_state, 'QUAD_CHECK') || strcmp(fsm.state, 'QUAD_CHECK')) && (k == N_preamble)
            nco_phase_pre_quad = nco_phase;
            min_val  = min(quad_counts);
            max_val  = max(quad_counts);
            min_locs = find(quad_counts == min_val);

            if numel(min_locs) == 1 && max_val > 0 && (min_val <= quad_min_ratio * max_val)
                quad_m          = min_locs(1);
                quad_k          = mod(quad_m - 3, 4);
                quad_unresolved = false;
                if quad_enable && quad_k > 0
                    nco_phase_next = mod(nco_phase_next + quad_k * (pi / 2) + pi, 2 * pi) - pi;
                end
            else
                quad_m          = NaN;
                quad_k          = NaN;
                quad_unresolved = true;
            end
            quad_corr_sym  = k;
            quad_done      = true;
            % Part 3d: Real post-correction check (start ema_var at 0.1, NOT at threshold)
            pub_lock_state = struct('ema_var', 0.1, 'bucket', 0, 'locked', false, 'lock_sym', NaN);
        end

        pub_costas_locked = quad_done && (~quad_unresolved) && (k > quad_corr_sym) && pub_lock_state.locked;
        sys_locked        = str_lock_k && pub_costas_locked;

        out_sym_internal(k)   = derot_k;
        slicer_sym(k)         = a_ref;
        costas_err(k)         = e_raw;
        nco_freq_log(k)       = nco_freq;
        nco_phase_log(k)      = nco_phase;
        costas_lock(k)        = pub_costas_locked;
        costas_settled_log(k) = acq_lock_state.locked;
        lock_detect(k)        = sys_locked;
        fsm_state_log(k)      = string(fsm.state);
        nco_phase             = nco_phase_next;
    end

    % Part 0f: Scale output to signed Q1.15 with documented output_scale factor
    out_scale = 0.50;
    if isfield(cfg, 'output_scale') && ~isempty(cfg.output_scale)
        out_scale = cfg.output_scale;
    end
    out_scaled = out_sym_internal * out_scale;

    do_q15 = true;
    if isfield(cfg, 'quantize_q15')
        do_q15 = cfg.quantize_q15;
    end
    if do_q15
        scale_q15  = 32768; % 2^15
        q_min      = -1.0;
        q_max      = 1.0 - (1.0 / scale_q15);
        re_q       = round(real(out_scaled) * scale_q15) / scale_q15;
        im_q       = round(imag(out_scaled) * scale_q15) / scale_q15;
        q15_clips  = sum((re_q < q_min) | (re_q > q_max)) + sum((im_q < q_min) | (im_q > q_max));
        out_q15    = min(max(re_q, q_min), q_max) + 1j * min(max(im_q, q_min), q_max);
    else
        out_q15   = out_scaled;
        q15_clips = 0;
    end

    first_pub_lock = find(costas_lock, 1, 'first');
    if isempty(first_pub_lock)
        pub_lock_from_start = NaN;
        pub_lock_from_load  = NaN;
    else
        pub_lock_from_start = first_pub_lock;
        pub_lock_from_load  = first_pub_lock - load_sym_idx;
    end

    rx_out.out_sym_i               = real(out_q15);
    rx_out.out_sym_q               = imag(out_q15);
    rx_out.out_sym_cplx            = out_q15;
    rx_out.output_scale            = out_scale;
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
    rx_out.quad_counts             = quad_counts;
    rx_out.quad_m                  = quad_m;
    rx_out.quad_k                  = quad_k;
    rx_out.quad_unresolved         = quad_unresolved;
    rx_out.quad_corr_sym           = quad_corr_sym;
    rx_out.nco_phase_pre_quad      = nco_phase_pre_quad;
    rx_out.str_sat_count           = str_res.sat_count;
    rx_out.costas_sat_count        = costas_sat_count;
end
