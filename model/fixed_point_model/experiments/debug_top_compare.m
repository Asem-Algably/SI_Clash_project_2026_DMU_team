% debug_top_compare.m
root_dir = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(root_dir, 'config'));
addpath(fullfile(root_dir, 'tx_channel'));
addpath(fullfile(root_dir, 'rx_blocks'));
addpath(fullfile(root_dir, 'utils_metrics'));

cfg = get_hw_config();
cfg.N_payload = 120;
[rx_samples, tx_payload] = generate_frame(cfg);

T = cfg;

% Initial States via Reset Call
r0.rst_ni = false;
[w.str_out,    st.str]     = step_str(r0, [], T);
[w.coarse_out, st.coarse]  = step_coarse_cfo(r0, [], T);
[w.derot_out,  st.derot]   = step_derotator(r0, [], T);
[w.costas_out, st.costas]  = step_costas(r0, [], T);
[w.wrap_out,   st.wrapper] = step_wrapper_fsm(r0, [], T);

mod_type_pipe = repmat(uint8(cfg.mod_type), 1, 8);

for clk = 1:800
    w_prev = w;
    in_val = (clk <= numel(rx_samples));
    if in_val
        in_i = real(rx_samples(clk));
        in_q = imag(rx_samples(clk));
    else
        in_i = T.fi(0, 'adc');
        in_q = T.fi(0, 'adc');
    end
    sob    = (clk == 1);
    rst_ni_eff = true;

    % 1. Step STR
    str_in.rst_ni            = rst_ni_eff;
    str_in.s_axis_valid_i    = in_val;
    str_in.s_axis_i_sample_i = in_i;
    str_in.s_axis_q_sample_i = in_q;
    str_in.start_of_burst_i  = sob;
    str_in.force_w_en_i      = false;
    str_in.force_w_i         = 0;
    str_in.loop_gain_i       = 0;
    [w.str_out, st.str]      = step_str(str_in, st.str, T);

    % 2. Step Coarse CFO
    coarse_in.rst_ni         = rst_ni_eff;
    coarse_in.start_i        = w_prev.wrap_out.coarse_start;
    coarse_in.s_axis_valid_i = w.str_out.m_axis_valid_o;
    coarse_in.s_axis_i_sym_i = w.str_out.m_axis_i_sym_o;
    coarse_in.s_axis_q_sym_i = w.str_out.m_axis_q_sym_o;
    coarse_in.force_cfo_en_i = false;
    coarse_in.force_cfo_i    = 0;
    [w.coarse_out, st.coarse] = step_coarse_cfo(coarse_in, st.coarse, T);

    % 3. Step Derotator
    fsm_curr     = double(w_prev.wrap_out.fsm_state);
    derot_active = (fsm_curr >= double(T.enc.fsm.COSTAS_ACQ));

    derot_in.rst_ni            = rst_ni_eff;
    derot_in.coarse_valid_i    = w.coarse_out.m_axis_valid_o;
    derot_in.coarse_word_i     = w.coarse_out.m_axis_cfo_o;
    derot_in.freq_adj_valid_i  = w_prev.costas_out.freq_adj_valid_o;
    derot_in.freq_adj_i        = w_prev.costas_out.freq_adj_o;
    derot_in.force_freq_en_i   = false;
    derot_in.force_freq_i      = 0;
    derot_in.phase_adj_valid_i = w_prev.costas_out.phase_adj_valid_o;
    derot_in.phase_adj_i       = w_prev.costas_out.phase_adj_o;

    if derot_active
        derot_in.s_axis_valid_i = w.str_out.m_axis_valid_o;
        derot_in.s_axis_i_sym_i = w.str_out.m_axis_i_sym_o;
        derot_in.s_axis_q_sym_i = w.str_out.m_axis_q_sym_o;
    else
        derot_in.s_axis_valid_i = false;
        derot_in.s_axis_i_sym_i = T.fi(0, 'str_sym');
        derot_in.s_axis_q_sym_i = T.fi(0, 'str_sym');
    end
    [w.derot_out, st.derot] = step_derotator(derot_in, st.derot, T);

    % 4. Step Costas
    mod_type_pipe = [uint8(cfg.mod_type), mod_type_pipe(1:end-1)];
    costas_in.rst_ni         = rst_ni_eff;
    costas_in.s_axis_valid_i = w.derot_out.m_axis_valid_o;
    costas_in.s_axis_i_sym_i = w.derot_out.m_axis_i_sym_o;
    costas_in.s_axis_q_sym_i = w.derot_out.m_axis_q_sym_o;
    costas_in.mode_i         = w_prev.wrap_out.costas_mode;
    costas_in.slicer_qpsk_i  = w_prev.wrap_out.slicer_qpsk;
    costas_in.preamble_end_i = w_prev.wrap_out.preamble_end;
    costas_in.mod_type_i     = mod_type_pipe(end);
    [w.costas_out, st.costas] = step_costas(costas_in, st.costas, T);

    % 5. Step Wrapper FSM
    wrap_in.rst_ni          = true;
    wrap_in.in_sample_valid = in_val;
    wrap_in.str_lock        = w.str_out.lock_o;
    wrap_in.coarse_valid    = w.coarse_out.m_axis_valid_o;
    wrap_in.coarse_word     = w.coarse_out.m_axis_cfo_o;
    wrap_in.str_valid       = w.str_out.m_axis_valid_o;
    wrap_in.derot_valid     = w.derot_out.m_axis_valid_o;
    wrap_in.derot_i         = w.derot_out.m_axis_i_sym_o;
    wrap_in.derot_q         = w.derot_out.m_axis_q_sym_o;
    wrap_in.costas_lock     = w.costas_out.lock_o;
    wrap_in.costas_int      = st.costas.acc;
    [w.wrap_out, st.wrapper] = step_wrapper_fsm(wrap_in, st.wrapper, T);

    if clk >= 760 && clk <= 775
        fprintf('[DBG_MAT][k=%d] fsm=%d str_val=%d str=(%d,%d) derot_val=%d derot=(%d,%d) out_val=%d out=(%d,%d) sl_qpsk=%d mode=%d pe=%d c_fval=%d f_adj=%d c_pval=%d p_adj=%d nco_w=%s nco_ph=%s\n', ...
            clk, double(w.wrap_out.fsm_state), ...
            uint8(w.str_out.m_axis_valid_o), int32(storedInteger(w.str_out.m_axis_i_sym_o)), int32(storedInteger(w.str_out.m_axis_q_sym_o)), ...
            uint8(w.derot_out.m_axis_valid_o), int32(storedInteger(w.derot_out.m_axis_i_sym_o)), int32(storedInteger(w.derot_out.m_axis_q_sym_o)), ...
            uint8(w.wrap_out.out_sym_valid), int32(storedInteger(w.wrap_out.out_sym_i)), int32(storedInteger(w.wrap_out.out_sym_q)), ...
            uint8(costas_in.slicer_qpsk_i), uint8(costas_in.mode_i), uint8(costas_in.preamble_end_i), ...
            uint8(w.costas_out.freq_adj_valid_o), int32(storedInteger(w.costas_out.freq_adj_o)), ...
            uint8(w.costas_out.phase_adj_valid_o), int32(storedInteger(w.costas_out.phase_adj_o)), ...
            dec2hex(typecast(int32(storedInteger(st.derot.fw)), 'uint32'), 8), ...
            dec2hex(typecast(int32(storedInteger(st.derot.theta)), 'uint32'), 8));
    end
end
