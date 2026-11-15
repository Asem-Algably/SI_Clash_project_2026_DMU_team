function export_block_test_vectors(N_payload_in)
    % EXPORT_BLOCK_TEST_VECTORS  Exports 5 dedicated hex vector files from a single golden model run.
    %
    % Files generated under code/tb/vectors/:
    %   1. tb_top_vec.hex     : Top-level synchronizer (sync_system_top)
    %   2. tb_str_vec.hex     : Symbol Timing Recovery (str_top)
    %   3. tb_coarse_vec.hex  : Coarse CFO Estimator (coarse_cfo_core)
    %   4. tb_derot_vec.hex   : Derotator / NCO (derotator)
    %   5. tb_costas_vec.hex  : Costas Carrier Loop (costas_top)

    if nargin < 1 || isempty(N_payload_in)
        N_payload_in = 120; % 190 preamble + 120 payload = ~1240 clocks (fast & rich)
    end

    root_dir = fullfile(fileparts(mfilename('fullpath')), '..');
    addpath(fullfile(root_dir, 'config'));
    addpath(fullfile(root_dir, 'tx_channel'));
    addpath(fullfile(root_dir, 'rx_blocks'));
    addpath(fullfile(root_dir, 'utils_metrics'));

    cfg = get_hw_config();
    cfg.N_payload = N_payload_in;

    out_dir = fullfile(root_dir, '..', '..', 'code', 'tb', 'vectors');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    fprintf('========================================================================\n');
    fprintf('  GENERATING TEST VECTORS FROM FIXED-POINT GOLDEN MODEL\n');
    fprintf('  Frame: 190 Preamble + %d Payload Symbols\n', cfg.N_payload);
    fprintf('  Destination: %s\n', out_dir);
    fprintf('========================================================================\n');

    % 1. Generate TX Frame and Channel Impairments
    [rx_samples, tx_payload] = generate_frame(cfg);
    N_clocks = numel(rx_samples) + 64; % Include pipeline flush margin

    % 2. Instrument & Run Cycle-Accurate Top
    T = cfg;
    R = T.rd;

    % Initial States via Reset Call
    r0.rst_ni = false;
    [w.str_out,    st.str]     = step_str(r0, [], T);
    [w.coarse_out, st.coarse]  = step_coarse_cfo(r0, [], T);
    [w.derot_out,  st.derot]   = step_derotator(r0, [], T);
    [w.costas_out, st.costas]  = step_costas(r0, [], T);
    [w.wrap_out,   st.wrapper] = step_wrapper_fsm(r0, [], T);

    % Prepare Vector Storage
    v_top    = cell(N_clocks, 1);
    v_str    = cell(N_clocks, 1);
    v_coarse = cell(N_clocks, 1);
    v_derot  = cell(N_clocks, 1);
    v_costas = cell(N_clocks, 1);

    last_smp_i = T.fi(0, 'in');
    last_smp_q = T.fi(0, 'in');
    mod_type_pipe = repmat(uint8(cfg.mod_type), 1, 8);

    fprintf('  Simulating %d clock cycles...\n', N_clocks);

    for clk = 1:N_clocks
        w_prev = w;

        % Top Inputs
        in_val = (clk <= numel(rx_samples));
        if in_val
            in_i = T.fi(real(rx_samples(clk)), 'in');
            in_q = T.fi(imag(rx_samples(clk)), 'in');
            last_smp_i = in_i;
            last_smp_q = in_q;
        else
            in_i = T.fi(0, 'in');
            in_q = T.fi(0, 'in');
        end
        sob = (clk == 1);

        flush_active = isfield(w_prev.wrap_out, 'flush_active') && logical(w_prev.wrap_out.flush_active);
        flush_rst    = isfield(w_prev.wrap_out, 'flush_rst')    && logical(w_prev.wrap_out.flush_rst);
        rst_ni_eff   = ~flush_rst;

        % 1. Step STR
        str_in.rst_ni       = rst_ni_eff;
        str_in.flush_active = flush_active;
        if flush_active
            str_in.s_axis_valid_i    = false;
            str_in.s_axis_i_sample_i = last_smp_i;
            str_in.s_axis_q_sample_i = last_smp_q;
        else
            str_in.s_axis_valid_i    = in_val;
            str_in.s_axis_i_sample_i = in_i;
            str_in.s_axis_q_sample_i = in_q;
        end
        str_in.force_w_en_i = false;
        str_in.force_w_i    = 0.25;

        [w.str_out, st.str] = step_str(str_in, st.str, T);

        % Record STR Vector
        % {valid_i[1], sample_i[12], sample_q[12], flush_act[1], exp_valid[1], exp_i[16], exp_q[16], exp_lock[1]}
        v_str{clk} = sprintf('%1x_%03x_%03x_%1x_%1x_%04x_%04x_%1x', ...
            uint8(str_in.s_axis_valid_i), ...
            uhex(str_in.s_axis_i_sample_i, 12), ...
            uhex(str_in.s_axis_q_sample_i, 12), ...
            uint8(flush_active), ...
            uint8(w.str_out.m_axis_valid_o), ...
            uhex(w.str_out.m_axis_i_sym_o, 16), ...
            uhex(w.str_out.m_axis_q_sym_o, 16), ...
            uint8(w.str_out.lock_o));

        % 2. Step Coarse CFO
        coarse_in.rst_ni         = rst_ni_eff;
        coarse_in.start_i        = w_prev.wrap_out.coarse_start;
        coarse_in.s_axis_valid_i = w.str_out.m_axis_valid_o;
        coarse_in.s_axis_i_sym_i = w.str_out.m_axis_i_sym_o;
        coarse_in.s_axis_q_sym_i = w.str_out.m_axis_q_sym_o;
        coarse_in.force_cfo_en_i = false;
        coarse_in.force_cfo_i    = 0;

        [w.coarse_out, st.coarse] = step_coarse_cfo(coarse_in, st.coarse, T);

        % Record Coarse Vector
        % {valid_i[1], sym_i[16], sym_q[16], start_i[1], exp_valid[1], exp_cfo[24]}
        v_coarse{clk} = sprintf('%1x_%04x_%04x_%1x_%1x_%06x', ...
            uint8(coarse_in.s_axis_valid_i), ...
            uhex(coarse_in.s_axis_i_sym_i, 16), ...
            uhex(coarse_in.s_axis_q_sym_i, 16), ...
            uint8(coarse_in.start_i), ...
            uint8(w.coarse_out.m_axis_valid_o), ...
            uhex(w.coarse_out.m_axis_cfo_o, 24));

        % 3. Step Derotator
        fsm_curr     = double(w_prev.wrap_out.fsm_state);
        derot_active = (fsm_curr >= double(T.enc.fsm.COSTAS_ACQ)); % Gated during early acquisition

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

        % Record Derotator Vector
        % {valid[1], sym_i[16], sym_q[16], c_val[1], c_word[24], f_val[1], f_adj[32], p_val[1], p_adj[32], exp_val[1], exp_i[16], exp_q[16]}
        v_derot{clk} = sprintf('%1x_%04x_%04x_%1x_%06x_%1x_%08x_%1x_%08x_%1x_%04x_%04x', ...
            uint8(derot_in.s_axis_valid_i), ...
            uhex(derot_in.s_axis_i_sym_i, 16), ...
            uhex(derot_in.s_axis_q_sym_i, 16), ...
            uint8(derot_in.coarse_valid_i), ...
            uhex(derot_in.coarse_word_i, 24), ...
            uint8(derot_in.freq_adj_valid_i), ...
            uhex(derot_in.freq_adj_i, 32), ...
            uint8(derot_in.phase_adj_valid_i), ...
            uhex(derot_in.phase_adj_i, 32), ...
            uint8(w.derot_out.m_axis_valid_o), ...
            uhex(w.derot_out.m_axis_i_sym_o, 16), ...
            uhex(w.derot_out.m_axis_q_sym_o, 16));

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

        % Record Costas Vector
        % {valid[1], sym_i[16], sym_q[16], mode[2], pe[1], mod[2], exp_fval[1], exp_fadj[32], exp_pval[1], exp_padj[32], exp_lock[1]}
        v_costas{clk} = sprintf('%1x_%04x_%04x_%01x_%1x_%01x_%1x_%08x_%1x_%08x_%1x', ...
            uint8(costas_in.s_axis_valid_i), ...
            uhex(costas_in.s_axis_i_sym_i, 16), ...
            uhex(costas_in.s_axis_q_sym_i, 16), ...
            uint8(costas_in.mode_i), ...
            uint8(costas_in.preamble_end_i), ...
            uint8(costas_in.mod_type_i), ...
            uint8(w.costas_out.freq_adj_valid_o), ...
            uhex(w.costas_out.freq_adj_o, 32), ...
            uint8(w.costas_out.phase_adj_valid_o), ...
            uhex(w.costas_out.phase_adj_o, 32), ...
            uint8(w.costas_out.lock_o));

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

        % Record Top Vector
        % {in_val[1], in_i[12], in_q[12], sob[1], exp_oval[1], exp_oi[16], exp_oq[16], exp_fsm[3], exp_lock[1]}
        v_top{clk} = sprintf('%1x_%03x_%03x_%1x_%1x_%04x_%04x_%1x_%1x', ...
            uint8(in_val), ...
            uhex(in_i, 12), ...
            uhex(in_q, 12), ...
            uint8(sob), ...
            uint8(w.wrap_out.out_sym_valid), ...
            uhex(w.wrap_out.out_sym_i, 16), ...
            uhex(w.wrap_out.out_sym_q, 16), ...
            uint8(w.wrap_out.fsm_state), ...
            uint8(w.wrap_out.lock_detect));
    end

    % 3. Write Files to Disk
    write_hex_file(fullfile(out_dir, 'tb_top_vec.hex'), v_top);
    write_hex_file(fullfile(out_dir, 'tb_str_vec.hex'), v_str);
    write_hex_file(fullfile(out_dir, 'tb_coarse_vec.hex'), v_coarse);
    write_hex_file(fullfile(out_dir, 'tb_derot_vec.hex'), v_derot);
    write_hex_file(fullfile(out_dir, 'tb_costas_vec.hex'), v_costas);

    fprintf('  [SUCCESS] All 5 test vector files successfully exported:\n');
    fprintf('    - tb_top_vec.hex    (%d vectors)\n', N_clocks);
    fprintf('    - tb_str_vec.hex    (%d vectors)\n', N_clocks);
    fprintf('    - tb_coarse_vec.hex (%d vectors)\n', N_clocks);
    fprintf('    - tb_derot_vec.hex  (%d vectors)\n', N_clocks);
    fprintf('    - tb_costas_vec.hex (%d vectors)\n', N_clocks);
    fprintf('========================================================================\n');
end

function h = uhex(val, bits)
    % UHEX Converts fixed-point or double to unsigned hex integer representation.
    if isa(val, 'embedded.fi')
        ival = double(storedInteger(val));
    else
        ival = round(double(val));
    end
    mod_val = mod(ival, 2^bits);
    if bits <= 4
        h = uint8(mod_val);
    elseif bits <= 12
        h = uint16(mod_val);
    elseif bits <= 16
        h = uint16(mod_val);
    elseif bits <= 24
        h = uint32(mod_val);
    else
        h = uint32(mod_val);
    end
end

function write_hex_file(filepath, lines_cell)
    fid = fopen(filepath, 'w');
    if fid == -1
        error('Could not open file for writing: %s', filepath);
    end
    for i = 1:numel(lines_cell)
        fprintf(fid, '%s\n', lines_cell{i});
    end
    fclose(fid);
end
