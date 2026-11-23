%% Experiment 1: Preamble Family Comparison (Period-2, Zadoff-Chu, Barker, PN)
clear; clc; close all;
cur_file = mfilename('fullpath');
if ~isempty(cur_file)
    search_dir = fileparts(cur_file);
else
    search_dir = pwd;
end
for depth = 1:4
    if exist(fullfile(search_dir, 'setup_project.m'), 'file')
        addpath(search_dir);
        break;
    end
    search_dir = fileparts(search_dir);
end
setup_project(false);

cfg = get_default_config();
cfg.snr_dB   = 18.0;
cfg.mod_type = 1; % 16-QAM payload

types = {'period2', 'zadoff_chu', 'barker', 'pn'};
disp(sprintf('%-14s | %-16s | %-18s | %-12s', 'Preamble Type', 'STR Lock (Syms)', 'Coarse CFO Err (%)', 'Payload EVM'));
disp(repmat('-', 1, 68));

for i = 1:numel(types)
    cfg.preamble_type = types{i};
    pre = generate_preamble(cfg.preamble_type, cfg.N_preamble);
    pay = generate_payload(cfg.mod_type, cfg.N_payload, cfg.seed);
    tx  = pulse_shape_rrc([pre; pay], cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
    rx  = apply_channel_impairments(tx, cfg);
    out = run_synchronizer_top(rx, true(size(rx)), cfg, pre);
    met = compute_evm_and_metrics(out, pay, cfg);
    disp(sprintf('%-14s | %-16d | %-18.4f | %.2f%%', ...
        types{i}, met.str_lock_syms, met.coarse_cfo_err_pct, met.evm_rms_pct));
end
