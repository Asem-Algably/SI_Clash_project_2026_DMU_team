function [rx_out, lg, T] = run_cycle_accurate_top(in_sample_iq, in_sample_valid, cfg)
    % RUN_CYCLE_ACCURATE_TOP  Master Clock-Accurate & Interface-Accurate Synchronizer Loop.
    %
    % Execution Methodology:
    %   - 1 iteration = 1 rising clock edge (125 MHz system clock).
    %   - Wire snapshot methodology (w_prev = w) models RTL non-blocking (<=) registers
    %     and guarantees order-independent execution between modules.
    %   - Input samples (in_sample_iq) arrive pre-scaled (/2, in_scale=0.5) and bounded
    %     to [-1, 1 - 2^-11] (signed Q1.11) by the front-end ADC / channel.
    %   - Datapath registers use pure 2's-complement wrapping with MSB guard bits;
    %     saturation is strictly confined to the STR and Costas PI loop filters.
    %
    % Inputs:
    %   in_sample_iq    - Complex baseband input samples at 4 sps (pre-scaled)
    %   in_sample_valid - Boolean valid strobe vector corresponding to input samples
    %   cfg             - Master system configuration struct
    %
    % Outputs:
    %   rx_out - Post-synchronization diagnostic output struct (symbols, EVM, lock metrics)
    %   lg     - Clock-cycle trace struct recording every internal signal transition
    %   T      - Hardware types, constants, and LUT definitions struct

    T = get_hw_types_and_cfg(cfg);

    in_sample_iq    = in_sample_iq(:);
    in_sample_valid = logical(in_sample_valid(:));
    in_scale        = T.in_scale;

    % Build cycle-by-cycle stimulus vectors (4 reset cycles + active burst + pipeline flush tail)
    n_reset  = 4;
    n_burst  = numel(in_sample_iq);
    n_tail   = T.lat.top_total + 16;
    N_clocks = n_reset + n_burst + n_tail;

    rst_n_vec = [false(n_reset, 1); true(n_burst + n_tail, 1)];
    valid_vec = [false(n_reset, 1); in_sample_valid; false(n_tail, 1)];
    smp_i_vec = [zeros(n_reset, 1); real(in_sample_iq); zeros(n_tail, 1)];
    smp_q_vec = [zeros(n_reset, 1); imag(in_sample_iq); zeros(n_tail, 1)];

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
    w.top_in.in_sample_i      = T.fi(0, 'in');
    w.top_in.in_sample_q      = T.fi(0, 'in');
    w.top_in.mod_type         = cfg.mod_type;

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

    n_str_sym          = 0;
    n_derot_sym        = 0;
    load_sym_idx       = NaN;
    coarse_done_sym    = NaN;
    costas_settle_sym  = NaN;
    quad_corr_sym      = NaN;
    nco_phase_pre_quad = NaN;
    prev_reported      = false;

    % =====================================================================
    % 2. MAIN HARDWARE CLOCK LOOP (1 iteration = 1 rising edge of clk)
    % =====================================================================
    for clk = 1:N_clocks
        w_prev = w;

        w_prev.top_in.rst_n            = rst_n_vec(clk);
        w_prev.top_in.in_sample_valid  = valid_vec(clk);
        w_prev.top_in.in_sample_i      = T.fi(smp_i_vec(clk), 'in');
        w_prev.top_in.in_sample_q      = T.fi(smp_q_vec(clk), 'in');
        w_prev.top_in.mod_type         = cfg.mod_type;

        str_in.rst_ni            = w_prev.top_in.rst_n;
        str_in.s_axis_valid_i    = w_prev.top_in.in_sample_valid;
        str_in.s_axis_i_sample_i = w_prev.top_in.in_sample_i;
        str_in.s_axis_q_sample_i = w_prev.top_in.in_sample_q;
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

        [w.str_out,    st.str]    = step_str(str_in, st.str, T);
        [w.coarse_out, st.coarse] = step_coarse_cfo(coarse_in, st.coarse, T);
        [w.derot_out,  st.derot]  = step_derotator(derot_in, st.derot, T);
        [w.costas_out, st.costas] = step_costas(costas_in, st.costas, T);
        [w.wrap_out,   st.wrap]   = step_wrapper_fsm(wrap_in, st.wrap, T);
        w.top_in = w_prev.top_in;

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
            str_sym_clk_idx(n_str_sym) = st.str.smp_reg;
        end

        if w.coarse_out.m_axis_valid_o && isnan(load_sym_idx)
            load_sym_idx    = max(n_str_sym, 1);
            coarse_done_sym = load_sym_idx;
        end

        if w.derot_out.m_axis_valid_o
            n_derot_sym = n_derot_sym + 1;
            derot_syms(n_derot_sym)    = double(w.derot_out.m_axis_i_sym_o) + 1j * double(w.derot_out.m_axis_q_sym_o);
            nco_freq_log(n_derot_sym)  = double(w.derot_out.freq_word_o);
            nco_phase_log(n_derot_sym) = w.derot_out.phase_rad_o;
            fsm_idx                    = min(max(double(w.wrap_out.fsm_state) + 1, 1), 6);
            fsm_state_log(n_derot_sym) = T.enc.fsm_names(fsm_idx);
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
    % 3. TRIM SYMBOL ARRAYS & RESTORE DISPLAY SCALE (* 2 FOR DOWNSTREAM SCORER)
    % =====================================================================
    N_sym       = min(n_str_sym, n_derot_sym);
    out_display = derot_syms(1:N_sym) / in_scale;

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
    rx_out.q11_clip_count        = 0;
    rx_out.q15_clip_count        = 0;
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
