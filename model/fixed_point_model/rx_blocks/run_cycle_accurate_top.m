function [rx_out, lg, T] = run_cycle_accurate_top(in_sample_iq, in_sample_valid, cfg)
    % RUN_CYCLE_ACCURATE_TOP  Master Clock-Accurate & Interface-Accurate Synchronizer Loop.
    %
    % Follows CLOCK_ACCURATE_MODELING_STANDARD.md (Rules 1-7):
    %   - 1 iteration = 1 rising edge of clk (125 MHz)
    %   - w_prev = w snapshot at the top of the loop (order-independent module execution)
    %   - Exact RTL port structs for STR, Coarse CFO, Derotator, Costas, and Wrapper FSM
    %   - Produces both the cycle-by-cycle RTL trace (lg) AND the symbol-rate rx_out struct
    %     for 100% compatibility with compute_evm_and_metrics, print_spec_report, and plots.

    if nargin < 3 || isempty(cfg)
        cfg = get_default_config();
    end
    T = get_hw_types_and_cfg(cfg);

    in_sample_iq    = in_sample_iq(:);
    in_sample_valid = logical(in_sample_valid(:));

    % =====================================================================
    % 0. WRAPPER INPUT RIGHT-SHIFT (>> 1 = / 2, +1 MSB Pad) & Q1.11 QUANTIZATION
    % =====================================================================
    in_scale     = T.in_scale;
    rx_in_scaled = in_sample_iq * in_scale;

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

    % Build cycle-by-cycle stimulus vectors (4 reset cycles + active burst + pipeline flush tail)
    n_reset  = 4;
    n_burst  = numel(rx_in_scaled);
    n_tail   = T.lat.top_total + 16;
    N_clocks = n_reset + n_burst + n_tail;

    rst_n_vec = [false(n_reset, 1); true(n_burst + n_tail, 1)];
    valid_vec = [false(n_reset, 1); in_sample_valid; false(n_tail, 1)];
    smp_i_vec = [zeros(n_reset, 1); real(rx_in_scaled); zeros(n_tail, 1)];
    smp_q_vec = [zeros(n_reset, 1); imag(rx_in_scaled); zeros(n_tail, 1)];

    % =====================================================================
    % 1. INITIALIZE ALL HARDWARE MODULES & WIRES (Active-Low Reset)
    % =====================================================================
    r0.rst_ni = false;
    [w.str_out,    st.str]    = step_str(r0, [], T);
    [w.coarse_out, st.coarse] = step_coarse_cfo(r0, [], T);
    [w.derot_out,  st.derot]  = step_derotator(r0, [], T);
    [w.costas_out, st.costas] = step_costas(r0, [], T);
    [w.wrap_out,   st.wrap]   = step_wrapper_fsm(r0, [], T);

    w.top_in.rst_n            = false;
    w.top_in.in_sample_valid  = false;
    w.top_in.in_sample_i      = T.fi(0, 'in', 'sat');
    w.top_in.in_sample_q      = T.fi(0, 'in', 'sat');
    w.top_in.mod_type         = cfg.mod_type;
    w.top_in.loop_gain        = cfg.mod_type;
    w.top_in.costas_loop_gain = cfg.mod_type;

    % Preallocate cycle-level trace (lg) and symbol-level buffers
    lg.str_valid    = false(N_clocks, 1);
    lg.str_i        = zeros(N_clocks, 1);
    lg.str_q        = zeros(N_clocks, 1);
    lg.str_lock     = false(N_clocks, 1);
    lg.coarse_valid = false(N_clocks, 1);
    lg.derot_valid  = false(N_clocks, 1);
    lg.out_valid    = false(N_clocks, 1);
    lg.out_i        = zeros(N_clocks, 1);
    lg.out_q        = zeros(N_clocks, 1);
    lg.lock_detect  = false(N_clocks, 1);
    lg.fsm_state    = zeros(N_clocks, 1);

    max_syms          = ceil(n_burst / 2) + 20;
    str_syms          = zeros(max_syms, 1);
    str_mu_log        = zeros(max_syms, 1);
    str_t_phase_log   = zeros(max_syms, 1);
    str_ted_log       = zeros(max_syms, 1);
    str_W_log         = zeros(max_syms, 1);
    str_v_pi_log      = zeros(max_syms, 1);
    str_lock_log      = false(max_syms, 1);
    str_lock_m_log    = zeros(max_syms, 1);
    str_sym_clk_idx   = zeros(max_syms, 1);

    derot_syms        = zeros(max_syms, 1);
    slicer_syms       = zeros(max_syms, 1);
    costas_err_log    = zeros(max_syms, 1);
    nco_freq_log      = zeros(max_syms, 1);
    nco_phase_log     = zeros(max_syms, 1);
    costas_lock_log   = false(max_syms, 1);
    costas_settle_log = false(max_syms, 1);
    sys_lock_log      = false(max_syms, 1);
    fsm_state_log     = strings(max_syms, 1);

    n_str_sym         = 0;
    n_derot_sym       = 0;
    load_sym_idx      = NaN;
    coarse_done_sym   = NaN;
    costas_settle_sym = NaN;
    quad_corr_sym     = NaN;
    nco_phase_pre_quad = NaN;
    prev_reported     = false;

    % =====================================================================
    % 2. MAIN HARDWARE CLOCK LOOP (1 iteration = 1 rising edge of clk)
    % =====================================================================
    for clk = 1:N_clocks
        % Step 2.1: Snapshot all wires on the rising clock edge (Rule 1)
        w_prev = w;

        % Step 2.2: Drive top-level input pins for this clock cycle
        w_prev.top_in.rst_n            = rst_n_vec(clk);
        w_prev.top_in.in_sample_valid  = valid_vec(clk);
        w_prev.top_in.in_sample_i      = T.fi(smp_i_vec(clk), 'in', 'sat');
        w_prev.top_in.in_sample_q      = T.fi(smp_q_vec(clk), 'in', 'sat');
        w_prev.top_in.mod_type         = cfg.mod_type;
        w_prev.top_in.loop_gain        = cfg.mod_type;
        w_prev.top_in.costas_loop_gain = cfg.mod_type;

        % Step 2.3: Combinational Inter-Module Wire Routing (from w_prev only!)
        str_in.rst_ni            = w_prev.top_in.rst_n;
        str_in.s_axis_valid_i    = w_prev.top_in.in_sample_valid;
        str_in.s_axis_i_sample_i = w_prev.top_in.in_sample_i;
        str_in.s_axis_q_sample_i = w_prev.top_in.in_sample_q;
        str_in.loop_gain_i       = w_prev.top_in.loop_gain;
        str_in.force_w_en_i      = false;
        str_in.force_w_i         = 0.25;

        coarse_in.rst_ni         = w_prev.top_in.rst_n;
        coarse_in.start_i        = w_prev.wrap_out.coarse_start;
        if strcmpi(cfg.coarse.tap_point, 'derotator')
            coarse_in.s_axis_valid_i = w_prev.derot_out.m_axis_valid_o;
            coarse_in.s_axis_i_sym_i = w_prev.derot_out.m_axis_i_sym_o;
            coarse_in.s_axis_q_sym_i = w_prev.derot_out.m_axis_q_sym_o;
        else
            coarse_in.s_axis_valid_i = w_prev.str_out.m_axis_valid_o;
            coarse_in.s_axis_i_sym_i = w_prev.str_out.m_axis_i_sym_o;
            coarse_in.s_axis_q_sym_i = w_prev.str_out.m_axis_q_sym_o;
        end
        coarse_in.force_cfo_en_i = false;
        coarse_in.force_cfo_i    = 0;

        derot_in.rst_ni            = w_prev.top_in.rst_n;
        derot_in.s_axis_valid_i    = w_prev.str_out.m_axis_valid_o;
        derot_in.s_axis_i_sym_i    = w_prev.str_out.m_axis_i_sym_o;
        derot_in.s_axis_q_sym_i    = w_prev.str_out.m_axis_q_sym_o;
        derot_in.coarse_valid_i    = w_prev.coarse_out.m_axis_valid_o;
        derot_in.coarse_word_i     = w_prev.coarse_out.m_axis_cfo_o;
        derot_in.freq_adj_valid_i  = w_prev.costas_out.freq_adj_valid_o;
        derot_in.freq_adj_i        = w_prev.costas_out.freq_adj_o;
        derot_in.phase_adj_valid_i = w_prev.costas_out.phase_adj_valid_o;
        derot_in.phase_adj_i       = w_prev.costas_out.phase_adj_o;
        derot_in.force_freq_en_i   = false;
        derot_in.force_freq_i      = 0;

        costas_in.rst_ni         = w_prev.top_in.rst_n;
        costas_in.s_axis_valid_i = w_prev.derot_out.m_axis_valid_o;
        costas_in.s_axis_i_sym_i = w_prev.derot_out.m_axis_i_sym_o;
        costas_in.s_axis_q_sym_i = w_prev.derot_out.m_axis_q_sym_o;
        costas_in.mod_type_i     = w_prev.top_in.mod_type;
        costas_in.costas_gain_i  = w_prev.top_in.costas_loop_gain;
        costas_in.mode_i         = w_prev.wrap_out.costas_mode;
        costas_in.slicer_qpsk_i  = w_prev.wrap_out.slicer_qpsk;
        costas_in.preamble_end_i = w_prev.wrap_out.preamble_end;

        wrap_in.rst_ni          = w_prev.top_in.rst_n;
        wrap_in.in_sample_valid = w_prev.top_in.in_sample_valid;
        wrap_in.str_valid       = w_prev.str_out.m_axis_valid_o;
        wrap_in.str_lock        = w_prev.str_out.lock_o;
        wrap_in.coarse_valid    = w_prev.coarse_out.m_axis_valid_o;
        wrap_in.coarse_word     = w_prev.coarse_out.m_axis_cfo_o;
        wrap_in.derot_valid     = w_prev.derot_out.m_axis_valid_o;
        wrap_in.derot_i         = w_prev.derot_out.m_axis_i_sym_o;
        wrap_in.derot_q         = w_prev.derot_out.m_axis_q_sym_o;
        wrap_in.costas_int      = w_prev.costas_out.int_o;
        wrap_in.costas_lock     = w_prev.costas_out.lock_o;

        % Step 2.4: Execute All Hardware Modules (Order-Independent!)
        [w.str_out,    st.str]    = step_str(str_in, st.str, T);
        [w.coarse_out, st.coarse] = step_coarse_cfo(coarse_in, st.coarse, T);
        [w.derot_out,  st.derot]  = step_derotator(derot_in, st.derot, T);
        [w.costas_out, st.costas] = step_costas(costas_in, st.costas, T);
        [w.wrap_out,   st.wrap]   = step_wrapper_fsm(wrap_in, st.wrap, T);
        w.top_in = w_prev.top_in;

        % Step 2.5: Record Cycle-Level Trace
        lg.str_valid(clk)    = w.str_out.m_axis_valid_o;
        lg.str_i(clk)        = double(w.str_out.m_axis_i_sym_o);
        lg.str_q(clk)        = double(w.str_out.m_axis_q_sym_o);
        lg.str_lock(clk)     = w.str_out.lock_o;
        lg.coarse_valid(clk) = w.coarse_out.m_axis_valid_o;
        lg.derot_valid(clk)  = w.derot_out.m_axis_valid_o;
        lg.out_valid(clk)    = w.wrap_out.out_sym_valid;
        lg.out_i(clk)        = double(w.wrap_out.out_sym_i);
        lg.out_q(clk)        = double(w.wrap_out.out_sym_q);
        lg.lock_detect(clk)  = w.wrap_out.lock_detect;
        lg.fsm_state(clk)    = double(w.wrap_out.fsm_state);

        % Step 2.6: Capture Symbol-Rate Logs for Compatibility with Report & Scorer
        if w.str_out.m_axis_valid_o
            n_str_sym = n_str_sym + 1;
            str_syms(n_str_sym)        = (double(w.str_out.m_axis_i_sym_o) + 1j * double(w.str_out.m_axis_q_sym_o)) / in_scale;
            str_mu_log(n_str_sym)      = double(w.str_out.mu_o);
            str_t_phase_log(n_str_sym) = st.str.t_phase;
            str_ted_log(n_str_sym)     = double(w.str_out.ted_err_o);
            str_W_log(n_str_sym)       = double(w.str_out.w_o);
            str_v_pi_log(n_str_sym)    = double(st.str.pi_reg);
            str_lock_log(n_str_sym)    = w.str_out.lock_o;
            str_lock_m_log(n_str_sym)  = double(st.str.lock.m) / T.str.K_pre_sc;
            str_sym_clk_idx(n_str_sym) = st.str.ip_smp(end);
        end

        if w.coarse_out.m_axis_valid_o && isnan(load_sym_idx)
            load_sym_idx    = max(n_str_sym, 1);
            coarse_done_sym = load_sym_idx;
        end

        if w.derot_out.m_axis_valid_o
            n_derot_sym = n_derot_sym + 1;
            derot_syms(n_derot_sym)      = double(w.derot_out.m_axis_i_sym_o) + 1j * double(w.derot_out.m_axis_q_sym_o);
            nco_freq_log(n_derot_sym)    = double(w.derot_out.freq_word_o);
            nco_phase_log(n_derot_sym)   = w.derot_out.phase_rad_o;
            fsm_idx                      = min(max(double(w.wrap_out.fsm_state) + 1, 1), 6);
            fsm_state_log(n_derot_sym)   = T.enc.fsm_names(fsm_idx);
        end

        if w_prev.derot_out.m_axis_valid_o && n_derot_sym >= 1
            slicer_syms(n_derot_sym)       = st.costas.a_ref;
            costas_err_log(n_derot_sym)    = double(w.costas_out.err_o);
            costas_settle_log(n_derot_sym) = w.costas_out.internal_lock_o;
            costas_lock_log(n_derot_sym)   = w.costas_out.lock_o;
            sys_lock_log(n_derot_sym)      = w.str_out.lock_o && w.costas_out.lock_o;

            if w.costas_out.internal_lock_o && isnan(costas_settle_sym)
                costas_settle_sym = n_derot_sym;
            end
        end

        if st.costas.reported && ~prev_reported
            quad_corr_sym      = max(n_derot_sym, 1);
            nco_phase_pre_quad = w.derot_out.phase_rad_o;
        end
        prev_reported = st.costas.reported;
    end

    % =====================================================================
    % 3. TRIM SYMBOL ARRAYS & APPLY WRAPPER <<1 OUTPUT SHIFT
    % =====================================================================
    N_sym = min(n_str_sym, n_derot_sym);
    out_sym_internal = derot_syms(1:N_sym);

    do_q15 = isfield(cfg, 'quantize_q15') && cfg.quantize_q15;
    if do_q15
        scale_q15 = 32768; % 2^15 for signed Q1.15 in [-1, 1 - 2^-15]
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

    % Left-shift by 1 (* 2) back to nominal constellation scale
    out_display = out_q15 / in_scale;

    str_res.symbols     = str_syms(1:N_sym);
    str_res.mu_log      = str_mu_log(1:N_sym);
    str_res.t_phase_log = str_t_phase_log(1:N_sym);
    str_res.ted_log     = str_ted_log(1:N_sym);
    str_res.W_log       = str_W_log(1:N_sym);
    str_res.v_pi_log    = str_v_pi_log(1:N_sym);
    str_res.lock_log    = str_lock_log(1:N_sym);
    str_res.lock_m_log  = str_lock_m_log(1:N_sym);
    str_res.sym_clk_idx = str_sym_clk_idx(1:N_sym);
    str_res.lock_sym    = st.str.lock.lock_sym;
    str_res.sat_count   = double(st.str.sat_cnt);

    costas_lock_trim = costas_lock_log(1:N_sym);
    first_pub_lock   = find(costas_lock_trim, 1, 'first');
    if isempty(first_pub_lock)
        pub_lock_from_start = NaN;
        pub_lock_from_load  = NaN;
    else
        pub_lock_from_start = first_pub_lock;
        pub_lock_from_load  = first_pub_lock - load_sym_idx;
    end

    rx_out.out_sym_i             = real(out_display);
    rx_out.out_sym_q             = imag(out_display);
    rx_out.out_sym_cplx          = out_display;
    rx_out.q11_clip_count        = q11_clips;
    rx_out.q15_clip_count        = q15_clips;
    rx_out.slicer_sym            = slicer_syms(1:N_sym);
    rx_out.out_sym_valid         = true(N_sym, 1);
    rx_out.coarse_cfo_est        = double(w.wrap_out.coarse_cfo_est);
    rx_out.fine_cfo_est          = double(w.wrap_out.fine_cfo_est);
    rx_out.lock_detect           = sys_lock_log(1:N_sym);
    rx_out.str                   = str_res;
    rx_out.costas_err            = costas_err_log(1:N_sym);
    rx_out.nco_freq_log          = nco_freq_log(1:N_sym);
    rx_out.nco_phase_log         = nco_phase_log(1:N_sym);
    rx_out.costas_lock           = costas_lock_trim;
    rx_out.costas_settled_log    = costas_settle_log(1:N_sym);
    rx_out.fsm_state_log         = fsm_state_log(1:N_sym);
    rx_out.str_lock_sym          = str_res.lock_sym;
    rx_out.coarse_done_sym       = coarse_done_sym;
    rx_out.load_sym_idx          = load_sym_idx;
    rx_out.costas_settle_sym     = costas_settle_sym;
    rx_out.costas_lock_sym       = pub_lock_from_start;
    rx_out.costas_lock_from_load = pub_lock_from_load;
    rx_out.quad_counts           = [double(st.costas.cnt_i), double(st.costas.cnt_q)];
    rx_out.quad_m                = st.costas.quad_q;
    rx_out.quad_k                = st.costas.quad_k;
    rx_out.quad_unresolved       = st.costas.unres || (~st.costas.reported);
    rx_out.quad_corr_sym         = quad_corr_sym;
    rx_out.nco_phase_pre_quad    = nco_phase_pre_quad;
    rx_out.str_sat_count         = str_res.sat_count;
    rx_out.costas_sat_count      = st.costas.sat_cnt;
    rx_out.cycle_log             = lg;
    rx_out.hw_lat_total          = T.lat.top_total;
    export_hardware_parameters(T);
end
