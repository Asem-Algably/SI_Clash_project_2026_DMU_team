function generate_uvm_cases(target, case_ids)
% GENERATE_UVM_CASES  Reads SV constrained-random configs/masks and runs the
% bit-exact MATLAB fixed-point golden model to generate complete UVM hex
% testcase suites under uvm/<mod>_uvm/cases/.
%
% Usage:
%   generate_uvm_cases()                 % build all 5 modules
%   generate_uvm_cases('all')            % build all 5 modules
%   generate_uvm_cases('top')            % build sync_system_top_uvm only
%   generate_uvm_cases('top', 1:7)       % build subset of top case IDs (for parallel workers)
%   generate_uvm_cases('top_list')       % refresh sync_system_top_uvm/cases/cases_list.txt
%   generate_uvm_cases('str'|'coarse'|'derot'|'costas')

    if nargin < 1 || isempty(target)
        target = 'all';
    end
    if nargin < 2
        case_ids = [];
    end
    target = lower(strtrim(string(target)));

    here      = fileparts(mfilename('fullpath'));
    fxp_root  = fullfile(here, '..');
    repo_root = fullfile(fxp_root, '..', '..');

    addpath(fullfile(fxp_root, 'config'));
    addpath(fullfile(fxp_root, 'tx_channel'));
    addpath(fullfile(fxp_root, 'rx_blocks'));
    addpath(fullfile(fxp_root, 'utils_metrics'));

    T = get_hw_config();

    fprintf('========================================================================\n');
    fprintf('  MATLAB UVM CASE BUILDER (target = %s)\n', target);
    fprintf('========================================================================\n');

    top_cases_dir = fullfile(repo_root, 'uvm', 'sync_system_top_uvm', 'cases');
    if target == "all" || target == "top"
        build_top_cases(top_cases_dir, T, case_ids);
    elseif target == "top_list"
        write_top_cases_list(top_cases_dir);
    end
    if target == "all" || target == "str"
        build_str_cases(fullfile(repo_root, 'uvm', 'str_uvm', 'cases'), T, case_ids);
    end
    if target == "all" || target == "coarse"
        build_coarse_cases(fullfile(repo_root, 'uvm', 'coarse_cfo_uvm', 'cases'), T, case_ids);
    end
    if target == "all" || target == "derot"
        build_derot_cases(fullfile(repo_root, 'uvm', 'derotator_uvm', 'cases'), T, case_ids);
    end
    if target == "all" || target == "costas"
        build_costas_cases(fullfile(repo_root, 'uvm', 'costas_uvm', 'cases'), T);
    end

    fprintf('========================================================================\n');
    fprintf('  MATLAB UVM CASE BUILDER FINISHED SUCCESSFULLY\n');
    fprintf('========================================================================\n');
end

% =========================================================================
% 1. TOP-LEVEL BUILDER (sync_system_top_uvm)
% =========================================================================
function build_top_cases(cases_dir, T, case_ids)
    t_start = tic;
    cases = load_cfg_cases(cases_dir, 'top');
    fmt = '%1x_%1x_%03x_%03x_%1x_%1x_%1x_%1x_%04x_%1x_%06x_%1x_%08x_%1x_%04x_%04x_%1x_%1x_%06x\n';

    for k = 1:numel(cases)
        c = cases(k);
        if ~isempty(case_ids) && ~ismember(c.id, case_ids)
            continue;
        end
        M = c.masks; % [rst_n, in_val, sob, mod_type, dft_sel, fw_en, fw, fc_en, fc, ff_en, ff]
        N = c.num_cycles;

        rst_n_vec  = M(:, 1) ~= 0;
        in_val_vec = M(:, 2) ~= 0;
        sob_vec    = M(:, 3) ~= 0;
        mod_vec    = uint8(M(:, 4));
        dft_vec    = uint8(M(:, 5));
        fw_en_vec  = M(:, 6) ~= 0;
        fw_vec     = uint32(M(:, 7));
        fc_en_vec  = M(:, 8) ~= 0;
        fc_vec     = uint32(M(:, 9));
        ff_en_vec  = M(:, 10) ~= 0;
        ff_vec     = uint32(M(:, 11));

        rx_samples = build_tx_rx_frame(c, in_val_vec, mod_vec, T);
        sim = run_full_chain_top(rx_samples, rst_n_vec, in_val_vec, sob_vec, mod_vec, ...
                                 fw_en_vec, fw_vec, fc_en_vec, fc_vec, ff_en_vec, ff_vec, T, false);

        out_mat = [ ...
            uint32(rst_n_vec).'; ...
            uint32(in_val_vec).'; ...
            sim.in_i_u.'; ...
            sim.in_q_u.'; ...
            uint32(sob_vec).'; ...
            uint32(mod_vec).'; ...
            uint32(dft_vec).'; ...
            uint32(fw_en_vec).'; ...
            fw_vec.'; ...
            uint32(fc_en_vec).'; ...
            fc_vec.'; ...
            uint32(ff_en_vec).'; ...
            ff_vec.'; ...
            sim.exp_val_u.'; ...
            sim.exp_i_u.'; ...
            sim.exp_q_u.'; ...
            sim.exp_state_u.'; ...
            sim.exp_lock_u.'; ...
            sim.exp_cfo_u.' ...
        ];

        out_name = sprintf('tb_top_tc_%02d.hex', c.id);
        write_hex_matrix(fullfile(cases_dir, out_name), fmt, out_mat);
        fprintf('    [TOP] tc_%02d/%02d (%d cycles, %.1fs)\n', c.id, numel(cases), N, toc(t_start));
    end

    if isempty(case_ids)
        write_top_cases_list(cases_dir);
    end
    fprintf('  [TOP] Finished subset in %.1fs -> %s\n', toc(t_start), cases_dir);
end

function write_top_cases_list(cases_dir)
    cases = load_cfg_cases(cases_dir, 'top');
    list_lines = cell(numel(cases), 1);
    for k = 1:numel(cases)
        list_lines{k} = sprintf('cases/tb_top_tc_%02d.hex', cases(k).id);
    end
    write_lines_file(fullfile(cases_dir, 'cases_list.txt'), list_lines);
    fprintf('  [TOP] Wrote cases_list.txt (%d entries)\n', numel(cases));
end

% =========================================================================
% 2. STR BUILDER (str_uvm)
% =========================================================================
function build_str_cases(cases_dir, T, case_ids)
    t_start = tic;
    cases = load_cfg_cases(cases_dir, 'str');
    list_lines = cell(numel(cases), 1);
    fmt = '%1x_%1x_%03x_%03x_%1x_%1x_%04x_%1x_%04x_%04x_%1x\n';

    for k = 1:numel(cases)
        c = cases(k);
        out_name = sprintf('tb_str_tc_%02d.hex', c.id);
        list_lines{k} = ['cases/' out_name];
        if ~isempty(case_ids) && ~ismember(c.id, case_ids)
            continue;
        end
        M = c.masks; % [rst_n, in_val, flush_active, fw_en, fw]
        N = c.num_cycles;

        rst_n_vec  = M(:, 1) ~= 0;
        in_val_vec = M(:, 2) ~= 0;
        flush_vec  = M(:, 3) ~= 0;
        fw_en_vec  = M(:, 4) ~= 0;
        fw_vec     = uint32(M(:, 5));

        rx_samples = build_tx_rx_frame(c, in_val_vec, zeros(N, 1, 'uint8'), T);
        rx_re_d    = double(real(rx_samples));
        rx_im_d    = double(imag(rx_samples));
        rx_re_u    = uhex_vec(real(storedInteger(rx_samples)), 12);
        rx_im_u    = uhex_vec(imag(storedInteger(rx_samples)), 12);

        r0.rst_ni = false;
        [~, st_str] = step_str(r0, [], T);
        last_re_d = 0.0; last_im_d = 0.0;
        last_re_u = uint32(0); last_im_u = uint32(0);
        smp_ptr   = 0;

        out_mat = zeros(11, N, 'uint32');
        for t = 1:N
            if ~rst_n_vec(t)
                val_i = false; re_d = 0.0; im_d = 0.0; re_u = uint32(0); im_u = uint32(0);
                last_re_d = 0.0; last_im_d = 0.0; last_re_u = uint32(0); last_im_u = uint32(0);
            elseif flush_vec(t)
                val_i = in_val_vec(t); re_d = last_re_d; im_d = last_im_d; re_u = last_re_u; im_u = last_im_u;
            elseif in_val_vec(t)
                val_i = true;
                smp_ptr = smp_ptr + 1;
                if smp_ptr <= numel(rx_re_d)
                    re_d = rx_re_d(smp_ptr); im_d = rx_im_d(smp_ptr);
                    re_u = rx_re_u(smp_ptr); im_u = rx_im_u(smp_ptr);
                else
                    re_d = 0.0; im_d = 0.0; re_u = uint32(0); im_u = uint32(0);
                end
                last_re_d = re_d; last_im_d = im_d; last_re_u = re_u; last_im_u = im_u;
            else
                val_i = false; re_d = 0.0; im_d = 0.0; re_u = uint32(0); im_u = uint32(0);
            end

            str_in.rst_ni            = rst_n_vec(t);
            str_in.flush_active      = flush_vec(t);
            str_in.s_axis_valid_i    = val_i;
            str_in.s_axis_i_sample_i = re_d;
            str_in.s_axis_q_sample_i = im_d;
            str_in.force_w_en_i      = fw_en_vec(t);
            str_in.force_w_i         = double(fw_vec(t)) * (2^-16);

            [str_out, st_str] = step_str(str_in, st_str, T);

            out_mat(:, t) = [ ...
                uint32(rst_n_vec(t)); uint32(val_i); re_u; im_u; uint32(flush_vec(t)); ...
                uint32(fw_en_vec(t)); fw_vec(t); uint32(str_out.m_axis_valid_o); ...
                uhex_s(str_out.m_axis_i_sym_o, 16); uhex_s(str_out.m_axis_q_sym_o, 16); ...
                uint32(str_out.lock_o) ...
            ];
        end

        write_hex_matrix(fullfile(cases_dir, out_name), fmt, out_mat);
    end

    if isempty(case_ids)
        write_lines_file(fullfile(cases_dir, 'cases_list.txt'), list_lines);
    end
    fprintf('  [STR] Built %d testcases in %.1fs -> %s\n', numel(cases), toc(t_start), cases_dir);
end

% =========================================================================
% 3. COARSE CFO BUILDER (coarse_cfo_uvm)
% =========================================================================
function build_coarse_cases(cases_dir, T, case_ids)
    t_start = tic;
    cases = load_cfg_cases(cases_dir, 'coarse');
    list_lines = cell(numel(cases), 1);
    fmt = '%1x_%1x_%04x_%04x_%1x_%1x_%06x_%1x_%06x\n';

    for k = 1:numel(cases)
        c = cases(k);
        out_name = sprintf('tb_coarse_tc_%02d.hex', c.id);
        list_lines{k} = ['cases/' out_name];
        if ~isempty(case_ids) && ~ismember(c.id, case_ids)
            continue;
        end
        M = c.masks; % [rst_n, start_i, s_valid, fc_en, fc_u24]
        N = c.num_cycles;

        rst_n_vec = M(:, 1) ~= 0;
        start_vec = M(:, 2) ~= 0;
        sval_vec  = M(:, 3) ~= 0;
        fc_en_vec = M(:, 4) ~= 0;
        fc_vec    = uint32(M(:, 5));

        if c.gen_mode == 0
            rx_samples = build_tx_rx_frame(c, sval_vec, zeros(N, 1, 'uint8'), T);
            sob_vec    = false(N, 1); sob_vec(1) = true;
            sim = run_full_chain_top(rx_samples, rst_n_vec, sval_vec, sob_vec, ...
                                     zeros(N, 1, 'uint8'), false(N, 1), zeros(N, 1, 'uint32'), ...
                                     false(N, 1), zeros(N, 1, 'uint32'), false(N, 1), zeros(N, 1, 'uint32'), T, true);
            out_mat = [ ...
                sim.coarse_rst_ni_u.'; ...
                sim.coarse_s_valid_u.'; ...
                sim.coarse_i_sym_u.'; ...
                sim.coarse_q_sym_u.'; ...
                sim.coarse_start_u.'; ...
                uint32(fc_en_vec).'; ...
                fc_vec.'; ...
                sim.coarse_exp_val_u.'; ...
                sim.coarse_exp_cfo_u.' ...
            ];
        else
            rng(uint32(c.seed), 'twister');
            r0.rst_ni = false;
            [~, st_c] = step_coarse_cfo(r0, [], T);
            cfo_norm  = double(c.cfo_q24) * (2^-24);
            phase0    = double(c.phase_q24) * (2^-24) * 2 * pi;
            snr_lin   = 10^((double(c.snr_x100) / 100.0) / 10.0);
            noise_std = 0.5 / sqrt(snr_lin);
            sym_idx   = 0;

            out_mat = zeros(9, N, 'uint32');
            for t = 1:N
                if rst_n_vec(t) && sval_vec(t)
                    sym_idx = sym_idx + 1;
                    ang  = 2 * pi * cfo_norm * (sym_idx - 1) + phase0;
                    i_d  = 0.5 * cos(ang) + noise_std * randn();
                    q_d  = 0.5 * sin(ang) + noise_std * randn();
                else
                    i_d = 0.0; q_d = 0.0;
                end

                cin.rst_ni         = rst_n_vec(t);
                cin.start_i        = start_vec(t);
                cin.s_axis_valid_i = sval_vec(t);
                cin.s_axis_i_sym_i = i_d;
                cin.s_axis_q_sym_i = q_d;
                cin.force_cfo_en_i = fc_en_vec(t);
                if fc_en_vec(t)
                    cin.force_cfo_i = u24_to_double(fc_vec(t));
                else
                    cin.force_cfo_i = 0.0;
                end

                [cout, st_c] = step_coarse_cfo(cin, st_c, T);

                out_mat(:, t) = [ ...
                    uint32(cin.rst_ni); uint32(cin.s_axis_valid_i); ...
                    uhex_s(T.fi(i_d, 'str_sym'), 16); uhex_s(T.fi(q_d, 'str_sym'), 16); ...
                    uint32(cin.start_i); uint32(cin.force_cfo_en_i); fc_vec(t); ...
                    uint32(cout.m_axis_valid_o); uhex_s(cout.m_axis_cfo_o, 24) ...
                ];
            end
        end

        write_hex_matrix(fullfile(cases_dir, out_name), fmt, out_mat);
    end

    if isempty(case_ids)
        write_lines_file(fullfile(cases_dir, 'cases_list.txt'), list_lines);
    end
    fprintf('  [COARSE] Built %d testcases in %.1fs -> %s\n', numel(cases), toc(t_start), cases_dir);
end

% =========================================================================
% 4. DEROTATOR BUILDER (derotator_uvm)
% =========================================================================
function build_derot_cases(cases_dir, T, case_ids)
    t_start = tic;
    cases = load_cfg_cases(cases_dir, 'derot');
    list_lines = cell(numel(cases), 1);
    fmt = '%1x_%1x_%04x_%04x_%1x_%06x_%1x_%08x_%1x_%08x_%1x_%08x_%1x_%04x_%04x\n';

    for k = 1:numel(cases)
        c = cases(k);
        out_name = sprintf('tb_derot_tc_%02d.hex', c.id);
        list_lines{k} = ['cases/' out_name];
        if ~isempty(case_ids) && ~ismember(c.id, case_ids)
            continue;
        end
        M = c.masks; % [rst_n, s_val, c_val, f_val, p_val, ff_en, ff_word]
        N = c.num_cycles;

        rst_n_vec = M(:, 1) ~= 0;
        sval_vec  = M(:, 2) ~= 0;
        cval_vec  = M(:, 3) ~= 0;
        fval_vec  = M(:, 4) ~= 0;
        pval_vec  = M(:, 5) ~= 0;
        ffen_vec  = M(:, 6) ~= 0;
        ff_vec    = uint32(M(:, 7));

        if c.gen_mode == 0
            rx_samples = build_tx_rx_frame(c, sval_vec, zeros(N, 1, 'uint8'), T);
            sob_vec    = false(N, 1); sob_vec(1) = true;
            sim = run_full_chain_top(rx_samples, rst_n_vec, sval_vec, sob_vec, ...
                                     zeros(N, 1, 'uint8'), false(N, 1), zeros(N, 1, 'uint32'), ...
                                     false(N, 1), zeros(N, 1, 'uint32'), false(N, 1), zeros(N, 1, 'uint32'), T, true);
            out_mat = [ ...
                sim.derot_rst_ni_u.'; ...
                sim.derot_s_valid_u.'; ...
                sim.derot_i_sym_u.'; ...
                sim.derot_q_sym_u.'; ...
                sim.derot_c_val_u.'; ...
                sim.derot_c_word_u.'; ...
                sim.derot_f_val_u.'; ...
                sim.derot_f_adj_u.'; ...
                uint32(ffen_vec).'; ...
                ff_vec.'; ...
                sim.derot_p_val_u.'; ...
                sim.derot_p_adj_u.'; ...
                sim.exp_val_u.'; ...
                sim.exp_i_u.'; ...
                sim.exp_q_u.' ...
            ];
        else
            rng(uint32(c.seed), 'twister');
            r0.rst_ni = false;
            [~, st_d] = step_derotator(r0, [], T);
            cfo_sign  = 1;
            p_cnt     = 0;

            out_mat = zeros(15, N, 'uint32');
            for t = 1:N
                if sval_vec(t) && rst_n_vec(t)
                    ang   = 2 * pi * rand();
                    mag   = 0.3 + 0.4 * rand();
                    i_d   = mag * cos(ang);
                    q_d   = mag * sin(ang);
                else
                    i_d = 0.0; q_d = 0.0;
                end

                if cval_vec(t)
                    c_d      = double(cfo_sign * c.cfo_q24) * (2^-24);
                    cfo_sign = -cfo_sign;
                else
                    c_d = 0.0;
                end

                if fval_vec(t)
                    f_d = rand() * 0.24 - 0.12;
                else
                    f_d = 0.0;
                end

                if pval_vec(t)
                    p_cnt = p_cnt + 1;
                    p_d   = 0.25 * mod(p_cnt, 4);
                else
                    p_d = 0.0;
                end

                din.rst_ni            = rst_n_vec(t);
                din.s_axis_valid_i    = sval_vec(t);
                din.s_axis_i_sym_i    = i_d;
                din.s_axis_q_sym_i    = q_d;
                din.coarse_valid_i    = cval_vec(t);
                din.coarse_word_i     = c_d;
                din.freq_adj_valid_i  = fval_vec(t);
                din.freq_adj_i        = f_d;
                din.force_freq_en_i   = ffen_vec(t);
                if ffen_vec(t)
                    din.force_freq_i = double(typecast(ff_vec(t), 'int32')) * (2^-32);
                else
                    din.force_freq_i = 0.0;
                end
                din.phase_adj_valid_i = pval_vec(t);
                din.phase_adj_i       = p_d;

                [dout, st_d] = step_derotator(din, st_d, T);

                out_mat(:, t) = [ ...
                    uint32(din.rst_ni); uint32(din.s_axis_valid_i); ...
                    uhex_s(T.fi(i_d, 'str_sym'), 16); uhex_s(T.fi(q_d, 'str_sym'), 16); ...
                    uint32(din.coarse_valid_i); uhex_s(T.fi(c_d, 'cfo'), 24); ...
                    uint32(din.freq_adj_valid_i); uhex_s(T.fi(f_d, 'freq_w'), 32); ...
                    uint32(din.force_freq_en_i); ff_vec(t); ...
                    uint32(din.phase_adj_valid_i); uhex_s(T.fi(p_d, 'phase'), 32); ...
                    uint32(dout.m_axis_valid_o); uhex_s(dout.m_axis_i_sym_o, 16); uhex_s(dout.m_axis_q_sym_o, 16) ...
                ];
            end
        end

        write_hex_matrix(fullfile(cases_dir, out_name), fmt, out_mat);
    end

    if isempty(case_ids)
        write_lines_file(fullfile(cases_dir, 'cases_list.txt'), list_lines);
    end
    fprintf('  [DEROT] Built %d testcases in %.1fs -> %s\n', numel(cases), toc(t_start), cases_dir);
end

% =========================================================================
% 5. COSTAS LOOP BUILDER (costas_uvm)
% =========================================================================
function build_costas_cases(cases_dir, T)
    t_start = tic;
    cases = load_cfg_cases(cases_dir, 'costas');
    list_lines = cell(numel(cases), 1);
    fmt = '%1x_%1x_%04x_%04x_%1x_%1x_%1x_%1x_%1x_%08x_%1x_%08x_%1x\n';

    for k = 1:numel(cases)
        c = cases(k);
        M = c.masks; % [rst_n, s_val, mode, pe, mod_type, sl_qpsk]
        N = c.num_cycles;

        rst_n_vec = M(:, 1) ~= 0;
        sval_vec  = M(:, 2) ~= 0;
        mode_vec  = uint8(M(:, 3));
        pe_vec    = M(:, 4) ~= 0;
        mod_vec   = uint8(M(:, 5));
        sl_vec    = M(:, 6) ~= 0;

        if c.gen_mode == 0
            rx_samples = build_tx_rx_frame(c, sval_vec, mod_vec, T);
            sob_vec    = false(N, 1); sob_vec(1) = true;
            sim = run_full_chain_top(rx_samples, rst_n_vec, sval_vec, sob_vec, ...
                                     mod_vec, false(N, 1), zeros(N, 1, 'uint32'), ...
                                     false(N, 1), zeros(N, 1, 'uint32'), false(N, 1), zeros(N, 1, 'uint32'), T, true);
            out_mat = [ ...
                sim.costas_rst_ni_u.'; ...
                sim.costas_s_valid_u.'; ...
                sim.costas_i_sym_u.'; ...
                sim.costas_q_sym_u.'; ...
                sim.costas_mode_u.'; ...
                sim.costas_pe_u.'; ...
                sim.costas_mod_u.'; ...
                sim.costas_sl_qpsk_u.'; ...
                sim.costas_exp_fval_u.'; ...
                sim.costas_exp_fadj_u.'; ...
                sim.costas_exp_pval_u.'; ...
                sim.costas_exp_padj_u.'; ...
                sim.costas_exp_lock_u.' ...
            ];
        else
            rng(uint32(c.seed), 'twister');
            r0.rst_ni = false;
            [~, st_cos] = step_costas(r0, [], T);
            phase0      = double(c.phase_q24) * (2^-24) * 2 * pi;
            snr_lin     = 10^((double(c.snr_x100) / 100.0) / 10.0);
            noise_std   = 0.15 / sqrt(snr_lin);
            burstB_val_cnt = 0;

            out_mat = zeros(13, N, 'uint32');
            for t = 1:N
                [re_d, im_d, burstB_val_cnt] = gen_costas_unit_symbol(...
                    c.corner_tag, t, rst_n_vec(t), sval_vec(t), mode_vec(t), ...
                    mod_vec(t), sl_vec(t), phase0, noise_std, st_cos, burstB_val_cnt, T);

                cosin.rst_ni         = rst_n_vec(t);
                cosin.s_axis_valid_i = sval_vec(t);
                cosin.s_axis_i_sym_i = re_d;
                cosin.s_axis_q_sym_i = im_d;
                cosin.mode_i         = mode_vec(t);
                cosin.preamble_end_i = pe_vec(t);
                cosin.mod_type_i     = mod_vec(t);
                cosin.slicer_qpsk_i  = sl_vec(t);

                [cosout, st_cos] = step_costas(cosin, st_cos, T);

                out_mat(:, t) = [ ...
                    uint32(cosin.rst_ni); uint32(cosin.s_axis_valid_i); ...
                    uhex_s(T.fi(re_d, 'rot_out'), 16); uhex_s(T.fi(im_d, 'rot_out'), 16); ...
                    uint32(cosin.mode_i); uint32(cosin.preamble_end_i); ...
                    uint32(cosin.mod_type_i); uint32(cosin.slicer_qpsk_i); ...
                    uint32(cosout.freq_adj_valid_o); uhex_s(cosout.freq_adj_o, 32); ...
                    uint32(cosout.phase_adj_valid_o); uhex_s(cosout.phase_adj_o, 32); ...
                    uint32(cosout.lock_o) ...
                ];
            end
        end

        out_name = sprintf('tb_costas_tc_%02d.hex', c.id);
        write_hex_matrix(fullfile(cases_dir, out_name), fmt, out_mat);
        list_lines{k} = ['cases/' out_name];
    end

    write_lines_file(fullfile(cases_dir, 'cases_list.txt'), list_lines);
    fprintf('  [COSTAS] Built %d testcases in %.1fs -> %s\n', numel(cases), toc(t_start), cases_dir);
end

% =========================================================================
% SHARED HELPER: CYCLE-ACCURATE FULL-CHAIN HARDWARE SIMULATOR
% =========================================================================
function sim = run_full_chain_top(rx_samples, rst_n_vec, in_val_vec, sob_vec, mod_vec, ...
                                  fw_en_vec, fw_vec, fc_en_vec, fc_vec, ff_en_vec, ff_vec, T, record_sub)
    N = numel(rst_n_vec);

    rx_re_d = double(real(rx_samples));
    rx_im_d = double(imag(rx_samples));
    rx_re_u = uhex_vec(real(storedInteger(rx_samples)), 12);
    rx_im_u = uhex_vec(imag(storedInteger(rx_samples)), 12);

    r0.rst_ni = false;
    [w.str_out,    st.str]     = step_str(r0, [], T);
    [w.coarse_out, st.coarse]  = step_coarse_cfo(r0, [], T);
    [w.derot_out,  st.derot]   = step_derotator(r0, [], T);
    [w.costas_out, st.costas]  = step_costas(r0, [], T);
    [w.wrap_out,   st.wrapper] = step_wrapper_fsm(r0, [], T);

    last_smp_i_d  = 0.0;
    last_smp_q_d  = 0.0;
    mod_pipe_len  = T.lat.str + T.lat.derot + 1;
    mod_type_pipe = zeros(1, mod_pipe_len, 'uint8');
    smp_ptr       = 0;

    z_u32 = zeros(N, 1, 'uint32');
    sim.in_i_u      = z_u32;
    sim.in_q_u      = z_u32;
    sim.exp_val_u   = z_u32;
    sim.exp_i_u     = z_u32;
    sim.exp_q_u     = z_u32;
    sim.exp_state_u = z_u32;
    sim.exp_lock_u  = z_u32;
    sim.exp_cfo_u   = z_u32;

    if record_sub
        sim.coarse_rst_ni_u  = z_u32; sim.coarse_s_valid_u = z_u32;
        sim.coarse_i_sym_u   = z_u32; sim.coarse_q_sym_u   = z_u32;
        sim.coarse_start_u   = z_u32; sim.coarse_exp_val_u = z_u32; sim.coarse_exp_cfo_u = z_u32;

        sim.derot_rst_ni_u  = z_u32; sim.derot_s_valid_u = z_u32;
        sim.derot_i_sym_u   = z_u32; sim.derot_q_sym_u   = z_u32;
        sim.derot_c_val_u   = z_u32; sim.derot_c_word_u  = z_u32;
        sim.derot_f_val_u   = z_u32; sim.derot_f_adj_u   = z_u32;
        sim.derot_p_val_u   = z_u32; sim.derot_p_adj_u   = z_u32;

        sim.costas_rst_ni_u   = z_u32; sim.costas_s_valid_u  = z_u32;
        sim.costas_i_sym_u    = z_u32; sim.costas_q_sym_u    = z_u32;
        sim.costas_mode_u     = z_u32; sim.costas_pe_u       = z_u32;
        sim.costas_mod_u      = z_u32; sim.costas_sl_qpsk_u  = z_u32;
        sim.costas_exp_fval_u = z_u32; sim.costas_exp_fadj_u = z_u32;
        sim.costas_exp_pval_u = z_u32; sim.costas_exp_padj_u = z_u32;
        sim.costas_exp_lock_u = z_u32;
    end

    for t = 1:N
        w_prev = w;

        if ~rst_n_vec(t) || ~in_val_vec(t)
            in_i_d = 0.0; in_q_d = 0.0; in_i_u = uint32(0); in_q_u = uint32(0);
        else
            smp_ptr = smp_ptr + 1;
            if smp_ptr <= numel(rx_re_d)
                in_i_d = rx_re_d(smp_ptr); in_q_d = rx_im_d(smp_ptr);
                in_i_u = rx_re_u(smp_ptr); in_q_u = rx_im_u(smp_ptr);
            else
                in_i_d = 0.0; in_q_d = 0.0; in_i_u = uint32(0); in_q_u = uint32(0);
            end
        end

        sim.in_i_u(t) = in_i_u;
        sim.in_q_u(t) = in_q_u;

        flush_rst_prev = logical(w_prev.wrap_out.flush_rst);
        rst_ni_eff     = rst_n_vec(t) && ~flush_rst_prev;

        fsm_prev     = double(w_prev.wrap_out.fsm_state);
        flush_active = (fsm_prev == double(T.enc.fsm.FLUSH));
        str_val_prev = logical(w_prev.str_out.m_axis_valid_o);
        str_lck_prev = logical(w_prev.str_out.lock_o);
        sym_cnt_prev = double(st.wrapper.sym_cnt);

        coarse_start_comb = (fsm_prev == double(T.enc.fsm.COARSE_EST)) || ...
                            ((fsm_prev == double(T.enc.fsm.ACQUIRE)) && ...
                             (str_lck_prev || (str_val_prev && (sym_cnt_prev + 1 >= T.preamble.N_A))));

        if fsm_prev == double(T.enc.fsm.COSTAS_ACQ)
            costas_mode_comb = uint8(T.enc.mode.ACQ);
        elseif fsm_prev == double(T.enc.fsm.TRACK)
            costas_mode_comb = uint8(T.enc.mode.TRACK);
        else
            costas_mode_comb = uint8(T.enc.mode.HOLD);
        end
        slicer_qpsk_comb = (fsm_prev ~= double(T.enc.fsm.TRACK));
        derot_active     = (fsm_prev >= double(T.enc.fsm.COSTAS_ACQ));

        % 1. STR inputs
        str_in.rst_ni         = rst_ni_eff;
        str_in.flush_active   = flush_active;
        str_in.s_axis_valid_i = in_val_vec(t);
        if flush_active
            str_in.s_axis_i_sample_i = last_smp_i_d;
            str_in.s_axis_q_sample_i = last_smp_q_d;
        else
            str_in.s_axis_i_sample_i = in_i_d;
            str_in.s_axis_q_sample_i = in_q_d;
        end
        str_in.force_w_en_i = fw_en_vec(t);
        if fw_en_vec(t)
            str_in.force_w_i = double(fw_vec(t)) * (2^-16);
        else
            str_in.force_w_i = 0.25;
        end

        % 2. Coarse CFO inputs
        coarse_in.rst_ni         = rst_ni_eff;
        coarse_in.start_i        = coarse_start_comb;
        coarse_in.s_axis_valid_i = str_val_prev;
        coarse_in.s_axis_i_sym_i = w_prev.str_out.m_axis_i_sym_o;
        coarse_in.s_axis_q_sym_i = w_prev.str_out.m_axis_q_sym_o;
        coarse_in.force_cfo_en_i = fc_en_vec(t);
        if fc_en_vec(t)
            coarse_in.force_cfo_i = u24_to_double(fc_vec(t));
        else
            coarse_in.force_cfo_i = 0.0;
        end

        % 3. Derotator inputs
        derot_in.rst_ni            = rst_ni_eff;
        derot_in.s_axis_valid_i    = derot_active && str_val_prev;
        derot_in.s_axis_i_sym_i    = w_prev.str_out.m_axis_i_sym_o;
        derot_in.s_axis_q_sym_i    = w_prev.str_out.m_axis_q_sym_o;
        derot_in.coarse_valid_i    = w_prev.coarse_out.m_axis_valid_o;
        derot_in.coarse_word_i     = w_prev.coarse_out.m_axis_cfo_o;
        derot_in.freq_adj_valid_i  = w_prev.costas_out.freq_adj_valid_o;
        derot_in.freq_adj_i        = w_prev.costas_out.freq_adj_o;
        derot_in.force_freq_en_i   = ff_en_vec(t);
        if ff_en_vec(t)
            derot_in.force_freq_i = double(typecast(ff_vec(t), 'int32')) * (2^-32);
        else
            derot_in.force_freq_i = 0.0;
        end
        derot_in.phase_adj_valid_i = w_prev.costas_out.phase_adj_valid_o;
        derot_in.phase_adj_i       = w_prev.costas_out.phase_adj_o;

        % 4. Costas inputs
        costas_in.rst_ni         = rst_ni_eff;
        costas_in.s_axis_valid_i = w_prev.derot_out.m_axis_valid_o;
        costas_in.s_axis_i_sym_i = w_prev.derot_out.m_axis_i_sym_o;
        costas_in.s_axis_q_sym_i = w_prev.derot_out.m_axis_q_sym_o;
        costas_in.mod_type_i     = mod_type_pipe(end);
        costas_in.mode_i         = costas_mode_comb;
        costas_in.slicer_qpsk_i  = slicer_qpsk_comb;
        costas_in.preamble_end_i = w_prev.wrap_out.preamble_end;

        % 5. Wrapper FSM inputs
        wrap_in.rst_ni          = rst_n_vec(t);
        wrap_in.start_of_burst  = sob_vec(t);
        wrap_in.in_sample_valid = in_val_vec(t);
        wrap_in.str_lock        = w_prev.str_out.lock_o;
        wrap_in.coarse_valid    = w_prev.coarse_out.m_axis_valid_o;
        wrap_in.coarse_word     = w_prev.coarse_out.m_axis_cfo_o;
        wrap_in.str_valid       = w_prev.str_out.m_axis_valid_o;
        wrap_in.derot_valid     = w_prev.derot_out.m_axis_valid_o;
        wrap_in.derot_i         = w_prev.derot_out.m_axis_i_sym_o;
        wrap_in.derot_q         = w_prev.derot_out.m_axis_q_sym_o;
        wrap_in.costas_lock     = w_prev.costas_out.lock_o;
        wrap_in.costas_int      = w_prev.costas_out.int_o;

        [w.str_out,    st.str]     = step_str(str_in, st.str, T);
        [w.coarse_out, st.coarse]  = step_coarse_cfo(coarse_in, st.coarse, T);
        [w.derot_out,  st.derot]   = step_derotator(derot_in, st.derot, T);
        [w.costas_out, st.costas]  = step_costas(costas_in, st.costas, T);
        [w.wrap_out,   st.wrapper] = step_wrapper_fsm(wrap_in, st.wrapper, T);

        if ~rst_n_vec(t)
            last_smp_i_d = 0.0; last_smp_q_d = 0.0;
            mod_type_pipe(:) = 0;
        else
            if in_val_vec(t)
                last_smp_i_d = in_i_d; last_smp_q_d = in_q_d;
            end
            mod_type_pipe = [mod_vec(t), mod_type_pipe(1:end-1)];
        end

        sim.exp_val_u(t)   = uint32(w.derot_out.m_axis_valid_o);
        sim.exp_i_u(t)     = uhex_s(w.derot_out.m_axis_i_sym_o, 16);
        sim.exp_q_u(t)     = uhex_s(w.derot_out.m_axis_q_sym_o, 16);
        sim.exp_state_u(t) = uint32(w.wrap_out.fsm_state);
        sim.exp_lock_u(t)  = uint32(logical(w.str_out.lock_o) && logical(w.costas_out.lock_o));
        sim.exp_cfo_u(t)   = uhex_s(w.coarse_out.m_axis_cfo_o, 24);

        if record_sub
            sim.coarse_rst_ni_u(t)  = uint32(coarse_in.rst_ni);
            sim.coarse_s_valid_u(t) = uint32(coarse_in.s_axis_valid_i);
            sim.coarse_i_sym_u(t)   = uhex_s(coarse_in.s_axis_i_sym_i, 16);
            sim.coarse_q_sym_u(t)   = uhex_s(coarse_in.s_axis_q_sym_i, 16);
            sim.coarse_start_u(t)   = uint32(coarse_in.start_i);
            sim.coarse_exp_val_u(t) = uint32(w.coarse_out.m_axis_valid_o);
            sim.coarse_exp_cfo_u(t) = sim.exp_cfo_u(t);

            sim.derot_rst_ni_u(t)  = uint32(derot_in.rst_ni);
            sim.derot_s_valid_u(t) = uint32(derot_in.s_axis_valid_i);
            sim.derot_i_sym_u(t)   = sim.coarse_i_sym_u(t);
            sim.derot_q_sym_u(t)   = sim.coarse_q_sym_u(t);
            sim.derot_c_val_u(t)   = uint32(derot_in.coarse_valid_i);
            sim.derot_c_word_u(t)  = uhex_s(derot_in.coarse_word_i, 24);
            sim.derot_f_val_u(t)   = uint32(derot_in.freq_adj_valid_i);
            sim.derot_f_adj_u(t)   = uhex_s(derot_in.freq_adj_i, 32);
            sim.derot_p_val_u(t)   = uint32(derot_in.phase_adj_valid_i);
            sim.derot_p_adj_u(t)   = uhex_s(derot_in.phase_adj_i, 32);

            sim.costas_rst_ni_u(t)   = uint32(costas_in.rst_ni);
            sim.costas_s_valid_u(t)  = uint32(costas_in.s_axis_valid_i);
            sim.costas_i_sym_u(t)    = uhex_s(costas_in.s_axis_i_sym_i, 16);
            sim.costas_q_sym_u(t)    = uhex_s(costas_in.s_axis_q_sym_i, 16);
            sim.costas_mode_u(t)     = uint32(costas_in.mode_i);
            sim.costas_pe_u(t)       = uint32(costas_in.preamble_end_i);
            sim.costas_mod_u(t)      = uint32(costas_in.mod_type_i);
            sim.costas_sl_qpsk_u(t)  = uint32(costas_in.slicer_qpsk_i);
            sim.costas_exp_fval_u(t) = uint32(w.costas_out.freq_adj_valid_o);
            sim.costas_exp_fadj_u(t) = uhex_s(w.costas_out.freq_adj_o, 32);
            sim.costas_exp_pval_u(t) = uint32(w.costas_out.phase_adj_valid_o);
            sim.costas_exp_padj_u(t) = uhex_s(w.costas_out.phase_adj_o, 32);
            sim.costas_exp_lock_u(t) = uint32(w.costas_out.lock_o);
        end
    end
end

% =========================================================================
% SHARED HELPER: REPRODUCIBLE TX/CHANNEL FRAME WITH RUNTIME MOD_TYPE SUPPORT
% =========================================================================
function rx_samples_fi = build_tx_rx_frame(c, in_val_vec, mod_vec, T)
    rng(uint32(c.seed), 'twister');

    cfg = T;
    cfg.seed         = uint32(c.seed);
    cfg.N_payload    = double(c.N_payload);
    cfg.snr_dB       = double(c.snr_x100) / 100.0;
    cfg.cfo_norm     = double(c.cfo_q24) * (2^-24);
    cfg.tau_offset   = double(c.tau_q16) / 65536.0;
    cfg.phase_offset = double(c.phase_q24) * (2^-24) * 2 * pi;

    valid_clks = find(in_val_vec);
    first_mod  = mod_vec(1);
    if all(mod_vec == first_mod)
        cfg.mod_type = double(first_mod);
        [rx_samples_fi, ~] = generate_frame(cfg);
        return;
    end

    sps = cfg.sps;
    N_alt = cfg.preamble.N_A + cfg.preamble.N_cfo + cfg.preamble.N_B;
    pre_alt = (1.0 - 1j) .* ((-1.0) .^ (0 : N_alt - 1).');
    pat_c   = [1.0 + 1j; -1.0 + 1j; 1.0 + 1j; 1.0 - 1j];
    pre_c   = repmat(pat_c, ceil(cfg.preamble.N_C / 4), 1);
    preamble_fi = fi([pre_alt; pre_c(1 : cfg.preamble.N_C)], 1, 16, 14);

    N_pay = cfg.N_payload;
    qpsk_levels  = [-1.0, 1.0];
    qam16_levels = [-1.0, -1.0/3.0, 1.0/3.0, 1.0];
    payload_raw  = complex(zeros(N_pay, 1));

    for sym_i = 1:N_pay
        smp_center = (cfg.N_preamble + sym_i - 1) * sps + 1;
        if smp_center <= numel(valid_clks)
            cur_m = mod_vec(valid_clks(smp_center));
        else
            cur_m = mod_vec(end);
        end
        if cur_m == 0
            payload_raw(sym_i) = qpsk_levels(randi([1, 2])) + 1j * qpsk_levels(randi([1, 2]));
        else
            payload_raw(sym_i) = qam16_levels(randi([1, 4])) + 1j * qam16_levels(randi([1, 4]));
        end
    end

    tx_symbols_fi = [preamble_fi; fi(payload_raw, 1, 16, 14)];

    h_rrc_raw = rcosdesign(cfg.rrc_alpha, cfg.rrc_span, sps, 'sqrt');
    h_rrc_fi  = fi(h_rrc_raw, 1, 16, 15);
    N_syms    = numel(tx_symbols_fi);
    up_sig    = complex(zeros(N_syms * sps, 1));
    up_sig(1 : sps : end) = double(tx_symbols_fi) * sqrt(sps);
    tx_shaped = conv(up_sig, double(h_rrc_fi), 'same');

    N_ch          = numel(tx_shaped);
    pad           = cfg.rrc_span * sps;
    tx_padded     = [zeros(pad, 1); tx_shaped; zeros(pad, 1)];
    N_pad         = numel(tx_padded);
    delay_samples = cfg.tau_offset * sps;
    k_freq        = [0 : ceil(N_pad/2)-1, -floor(N_pad/2) : -1].' / N_pad;
    rx_del_pad    = ifft(fft(tx_padded) .* exp(-1j * 2 * pi * k_freq * delay_samples));
    rx_delayed    = rx_del_pad(pad + 1 : pad + N_ch);

    n_vec     = (0 : N_ch - 1).';
    phase_vec = 2 * pi * (cfg.cfo_norm / sps) * n_vec + cfg.phase_offset;
    rx_rot    = rx_delayed .* exp(1j * phase_vec);

    sig_pwr   = mean(abs(rx_rot(pad + 1 : max(N_ch - pad, pad + 1))).^2);
    snr_lin   = 10^(cfg.snr_dB / 10);
    if strcmpi(cfg.snr_def, 'sample')
        noise_pwr = sig_pwr / snr_lin;
    else
        noise_pwr = (sig_pwr * sps) / snr_lin;
    end
    noise_raw      = sqrt(noise_pwr / 2) * (randn(N_ch, 1) + 1j * randn(N_ch, 1));
    rx_matched_raw = conv(rx_rot + noise_raw, double(h_rrc_fi) / sqrt(sps), 'same');

    clip_lim      = 2.0 - 2^(-11);
    rx_re         = min(max(real(rx_matched_raw), -2.0), clip_lim) * cfg.in_scale;
    rx_im         = min(max(imag(rx_matched_raw), -2.0), clip_lim) * cfg.in_scale;
    rx_samples_fi = complex(fi(rx_re, 1, 12, 11), fi(rx_im, 1, 12, 11));
end

% =========================================================================
% COSTAS UNIT SYMBOL GENERATOR (corner_tag 3..7)
% =========================================================================
function [re_d, im_d, burstB_val_cnt] = gen_costas_unit_symbol(...
    corner_tag, t_sv, rst_n, s_val, mode_i, mod_i, sl_qpsk, phase0, noise_std, st_cos, burstB_val_cnt, T)

    t0 = t_sv - 1;

    if ~rst_n || ~s_val
        re_d = 0.0; im_d = 0.0;
        if t0 == 168
            burstB_val_cnt = 0;
        end
        return;
    end

    qpsk_pts  = [-0.5, 0.5];
    qam16_pts = [-0.5, -5461/32768, 5461/32768, 0.5];

    if corner_tag == 3
        if mode_i == T.enc.mode.ACQ
            if t0 >= 176
                burstB_val_cnt = burstB_val_cnt + 1;
                extra_ph = 0.0;
            else
                extra_ph = 0.0;
            end
            ang  = phase0 + extra_ph + 0.04 * (2 * rand() - 1);
            cplx = (0.5 + 0.5j) * exp(1j * ang) + noise_std * (randn() + 1j * randn());
        else
            if mod_i == 0 || sl_qpsk
                cplx = qpsk_pts(randi(2)) + 1j * qpsk_pts(randi(2));
            else
                cplx = qam16_pts(randi(4)) + 1j * qam16_pts(randi(4));
            end
            cplx = cplx * exp(1j * (0.04 * (2 * rand() - 1))) + 0.35 * noise_std * (randn() + 1j * randn());
        end

    elseif corner_tag == 4
        if mode_i == T.enc.mode.ACQ
            if ~st_cos.li.locked
                cplx = 0.5 + 0.5j;
            else
                % Alternate (+1,+1) and (-1,-1) after lock_int so sym 34 at t0=136 lands on cnt==0 before pe=1 at t0=140
                si = -1 + 2 * (double(st_cos.cnt_i) <= 0);
                cplx = 0.5 * si * (1 + 1j);
            end
        else
            cplx = qam16_pts(randi(4)) + 1j * qam16_pts(randi(4));
        end

    elseif corner_tag == 5
        if t0 < 170
            if mod(t0, 11) == 0
                cplx = 0.42 + 0.56j;
            elseif mode_i == T.enc.mode.ACQ
                cplx = 0.02 + 0.96j;
            else
                cplx = 0.36 + 0.96j;
            end
        else
            if mod(t0, 11) == 0
                cplx = 0.56 + 0.42j;
            elseif mode_i == T.enc.mode.ACQ
                cplx = 0.96 + 0.02j;
            else
                cplx = 0.96 + 0.36j;
            end
        end

    elseif corner_tag == 6
        if t0 < 60
            cplx = (0.5 + 0.5j) + 0.25 * noise_std * (randn() + 1j * randn());
        elseif t0 < 140
            idx = mod(t0 - 60, 16);
            cplx = qam16_pts(floor(idx / 4) + 1) + 1j * qam16_pts(mod(idx, 4) + 1);
        elseif t0 < 220
            cplx = qam16_pts(randi(4)) + 1j * qam16_pts(randi(4));
            cplx = cplx + 0.02 * ((2 * rand() - 1) + 1j * (2 * rand() - 1));
        else
            cplx = 0.96 + 0.36j;
        end

    else
        if t0 < 55 || (t0 >= 185 && t0 < 235)
            cplx = (0.5 + 0.5j) + 0.3 * noise_std * (randn() + 1j * randn());
        elseif mod(t0, 4) == 0
            idx = mod(floor(t0 / 4), 16);
            cplx = qam16_pts(floor(idx / 4) + 1) + 1j * qam16_pts(mod(idx, 4) + 1);
        else
            cplx = qam16_pts(randi(4)) + 1j * qam16_pts(randi(4));
            cplx = cplx + 0.04 * ((2 * rand() - 1) + 1j * (2 * rand() - 1));
        end
    end

    clip_max = 1.0 - 2^-15;
    re_d = min(max(real(cplx), -1.0), clip_max);
    im_d = min(max(imag(cplx), -1.0), clip_max);
end

% =========================================================================
% LOW-LEVEL FILE PARSING & FAST VECTORIZED HEX HELPERS
% =========================================================================
function cases = load_cfg_cases(cases_dir, mod_tag)
    d = dir(fullfile(cases_dir, 'cfg_tc_*.txt'));
    if isempty(d)
        error('No cfg_tc_*.txt files found in %s', cases_dir);
    end

    ids = zeros(numel(d), 1);
    for i = 1:numel(d)
        tok = regexp(d(i).name, 'cfg_tc_\s*(\d+)\.txt', 'tokens', 'once');
        if isempty(tok), ids(i) = i; else, ids(i) = str2double(tok{1}); end
    end
    [~, order] = sort(ids);
    d = d(order); ids = ids(order);

    switch mod_tag
        case 'top',    scan_fmt = '%f %f %f %x %x %f %x %f %x %f %x'; num_cols = 11;
        case 'str',    scan_fmt = '%f %f %f %f %x';                    num_cols = 5;
        case 'coarse', scan_fmt = '%f %f %f %f %x';                    num_cols = 5;
        case 'derot',  scan_fmt = '%f %f %f %f %f %f %x';              num_cols = 7;
        case 'costas', scan_fmt = '%f %f %f %f %f %f';                 num_cols = 6;
        otherwise,     error('Unknown mod_tag: %s', mod_tag);
    end

    cases = repmat(struct('id', 0, 'seed', 0, 'gen_mode', 0, 'corner_tag', 0, ...
                          'N_payload', 0, 'snr_x100', 0, 'cfo_q24', 0, ...
                          'tau_q16', 0, 'phase_q24', 0, 'num_cycles', 0, 'masks', []), numel(d), 1);

    for i = 1:numel(d)
        fpath = fullfile(cases_dir, d(i).name);
        fid = fopen(fpath, 'r');
        if fid == -1, error('Cannot open %s', fpath); end

        hdr_vals = [];
        while ~feof(fid)
            ln = fgetl(fid);
            if ~ischar(ln), break; end
            ln = strtrim(ln);
            if isempty(ln) || startsWith(ln, '#'), continue; end
            if startsWith(ln, 'CFG')
                hdr_vals = sscanf(ln(4:end), '%f');
                break;
            end
        end
        if numel(hdr_vals) < 9
            fclose(fid);
            error('Malformed CFG header in %s', fpath);
        end

        N_cyc = hdr_vals(9);
        raw_cols = textscan(fid, scan_fmt, N_cyc, 'CollectOutput', false);
        fclose(fid);

        masks = zeros(N_cyc, num_cols);
        for col = 1:num_cols
            masks(:, col) = double(raw_cols{col});
        end

        cases(i).id         = ids(i);
        cases(i).seed       = uint32(hdr_vals(1));
        cases(i).gen_mode   = hdr_vals(2);
        cases(i).corner_tag = hdr_vals(3);
        cases(i).N_payload  = hdr_vals(4);
        cases(i).snr_x100   = hdr_vals(5);
        cases(i).cfo_q24    = hdr_vals(6);
        cases(i).tau_q16    = hdr_vals(7);
        cases(i).phase_q24  = hdr_vals(8);
        cases(i).num_cycles = N_cyc;
        cases(i).masks      = masks;
    end
end

function d = u24_to_double(val_u24)
    v = int32(mod(double(val_u24), 2^24));
    if v >= 2^23, v = v - 2^24; end
    d = double(v) * (2^-24);
end

function u = uhex_s(fi_val, bits)
    u = uint32(mod(int64(storedInteger(fi_val)), bitshift(int64(1), bits)));
end

function u = uhex_vec(int_vec, bits)
    u = uint32(mod(int64(int_vec), bitshift(int64(1), bits)));
end

function write_hex_matrix(fpath, fmt, mat)
    fid = fopen(fpath, 'w');
    if fid == -1, error('Cannot open %s for writing', fpath); end
    fprintf(fid, fmt, mat);
    fclose(fid);
end

function write_lines_file(fpath, lines)
    fid = fopen(fpath, 'w');
    if fid == -1, error('Cannot open %s for writing', fpath); end
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    fclose(fid);
end
