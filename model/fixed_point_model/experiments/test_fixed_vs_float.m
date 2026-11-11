%% Experiment: Cycle-Accurate Fixed-Point vs. Floating-Point Verification
clear; clc; close all;
cur_file = mfilename('fullpath');
if ~isempty(cur_file), search_dir = fileparts(cur_file); else, search_dir = pwd; end
for depth = 1:4
    if exist(fullfile(search_dir, 'setup_project.m'), 'file')
        addpath(search_dir);
        break;
    end
    search_dir = fileparts(search_dir);
end
setup_project(false);

disp('====================================================================================================');
disp('  SI-CLASH CYCLE-ACCURATE FIXED-POINT vs. FLOATING-POINT BENCHMARK (QPSK & 16-QAM)');
disp('====================================================================================================');
disp(sprintf('  %-6s | %-14s | %-10s | %-8s | %-8s | %-10s | %-10s | %-8s', ...
    'Mod', 'Exec Mode', 'RMS EVM', 'SER', 'STR Lock', 'Cos Lock', 'Coarse Err', 'Unres'));
disp(repmat('-', 1, 100));

modes = {'float_symbol', 'float_cycle', 'fixed_cycle'};
for mod_t = [0, 1]
    cfg = get_default_config();
    cfg.mod_type = mod_t;
    cfg.snr_dB   = 18.0;
    cfg.snr_def  = 'sample';

    pre = generate_preamble(cfg.preamble_type, cfg.N_preamble, cfg);
    [pay, const] = generate_payload(cfg.mod_type, cfg.N_payload, cfg.seed, cfg.norm_mode);
    tx_w = pulse_shape_rrc([pre; pay], cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
    meas_esn0 = measure_es_n0(tx_w, cfg);

    cfg_ch = cfg; cfg_ch.quantize_q11 = false;
    [rx_w, ~] = apply_channel_impairments(tx_w, cfg_ch);

    for m = 1:numel(modes)
        cfg_run = cfg;
        cfg_run.exec_mode = modes{m};
        out_r = run_synchronizer_top(rx_w, true(size(rx_w)), cfg_run, []);
        met_r = compute_evm_and_metrics(out_r, pay, cfg_run, meas_esn0);
        disp(sprintf('  %-6s | %-14s | %8.2f %% | %8.4f | %4d sym | %6d sym | %8.4f %% | %5d', ...
            const.name, modes{m}, met_r.evm_rms_pct, met_r.ser, ...
            met_r.str_lock_syms, met_r.costas_lock_syms, met_r.coarse_cfo_err_pct, double(out_r.quad_unresolved)));
    end
    disp(repmat('-', 1, 100));
end
