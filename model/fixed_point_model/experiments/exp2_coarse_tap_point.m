%% Experiment 2: Coarse CFO Tap Point (Interpolator Output vs. Derotator Output)
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
cfo_sweep = linspace(-0.095, 0.095, 11);
taps = {'interpolator'};
err_mat = zeros(numel(taps), numel(cfo_sweep));

for t = 1:numel(taps)
    for c = 1:numel(cfo_sweep)
        cfg_run = cfg;
        cfg_run.coarse.tap_point = taps{t};
        cfg_run.cfo_norm = cfo_sweep(c);
        pre = generate_preamble(cfg_run.preamble_type, cfg_run.N_preamble);
        pay = generate_payload(cfg_run.mod_type, 400, cfg_run.seed);
        tx  = pulse_shape_rrc([pre; pay], cfg_run.rrc_alpha, cfg_run.rrc_span, cfg_run.sps, 'tx');
        rx  = apply_channel_impairments(tx, cfg_run);
        out = run_cycle_accurate_top(rx, true(size(rx)), cfg_run);
        err_mat(t, c) = 100 * abs(out.coarse_cfo_est - cfg_run.cfo_norm);
    end
end

figure('Color', 'w', 'Name', 'Section 1.3: Coarse CFO Tap Point Comparison');
plot(cfo_sweep * 100, err_mat(1,:), 'b-o', 'LineWidth', 1.5, 'DisplayName', 'Interpolator Tap'); hold on;
plot(cfo_sweep * 100, err_mat(2,:), 'r--s', 'LineWidth', 1.5, 'DisplayName', 'Derotator Tap');
yline(0.5, 'k:', 'CP3 Limit (0.5% R_{sym})');
grid on; xlabel('True Injected CFO (% of R_{sym})'); ylabel('Coarse CFO Estimation Error (% of R_{sym})');
title('Coarse CFO Tap Point Comparison Across Capture Range'); legend('Location', 'best');
