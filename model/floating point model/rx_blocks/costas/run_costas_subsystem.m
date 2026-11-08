function costas_out = run_costas_subsystem(sym_in, cfg, cfo_init_norm, train_syms)
    sym_in = sym_in(:);
    N_sym  = numel(sym_in);
    if nargin < 3, cfo_init_norm = 0.0; end
    if nargin < 4, train_syms = []; end

    pipe_delay = 0;
    if isfield(cfg.costas, 'pipe_delay')
        pipe_delay = max(round(cfg.costas.pipe_delay), 0);
    end
    comp_delay = isfield(cfg.costas, 'compensate_delay') && cfg.costas.compensate_delay;

    K_nco = 2 * pi;
    [Kp, Ki] = compute_loop_gains(cfg.costas.Bn_Ts, cfg.costas.zeta, cfg.costas.Kp_ted, K_nco, pipe_delay, comp_delay);

    err_fifo   = zeros(max(pipe_delay, 1), 1);
    phase_nco  = 0.0;
    int_state  = 0.0;
    lock_state = struct('ema_var', 0.1, 'bucket', 0, 'locked', false, 'lock_sym', NaN);

    sym_derot  = zeros(N_sym, 1);
    decisions  = zeros(N_sym, 1);
    err_log    = zeros(N_sym, 1);
    freq_log   = zeros(N_sym, 1);
    phase_log  = zeros(N_sym, 1);
    lock_log   = false(N_sym, 1);

    for k = 1:N_sym
        y_k = derotator(sym_in(k), phase_nco, cfg.costas.derot_mode);
        if k <= numel(train_syms) && ~isempty(train_syms)
            a_k = train_syms(k);
        else
            a_k = qam_slicer(y_k, cfg.mod_type);
        end
        e_raw = costas_phase_detector(y_k, a_k);

        if pipe_delay > 0
            e_loop   = err_fifo(1);
            err_fifo = [err_fifo(2:end); e_raw];
        else
            e_loop   = e_raw;
        end

        [v_pi, int_state] = pi_loop_filter(e_loop, int_state, Kp, Ki);

        [phase_next, f_word] = nco_32bit(phase_nco, cfo_init_norm, v_pi, false);

        lock_state = dynamic_lock_detector(e_raw, lock_state, ...
            cfg.lock.costas_ema_alpha, cfg.lock.costas_var_thresh, cfg.lock.costas_confirm_cnt, k);

        sym_derot(k) = y_k;
        decisions(k) = a_k;
        err_log(k)   = e_raw;
        freq_log(k)  = f_word;
        phase_log(k) = phase_nco;
        lock_log(k)  = lock_state.locked;
        phase_nco    = phase_next;
    end

    costas_out.sym_derot = sym_derot;
    costas_out.decisions = decisions;
    costas_out.err_log   = err_log;
    costas_out.freq_log  = freq_log;
    costas_out.phase_log = phase_log;
    costas_out.lock_log  = lock_log;
    costas_out.fine_cfo  = cfo_init_norm + int_state;
    costas_out.lock_sym  = lock_state.lock_sym;
end
