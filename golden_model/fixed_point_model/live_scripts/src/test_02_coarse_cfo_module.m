%% Isolated Component Test 02: Coarse CFO Estimator & Preamble Benchmark (CP3)
% Compares Period-2, Zadoff-Chu, Barker, and PN preambles across 0 to 20 dB SNR
% against the CP3 accuracy target (<= 0.5% of R_sym).

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

%% 1. Monte Carlo SNR Sweep Across Candidate Preamble Families
% Evaluate dual-lag (D1=2, D2=8) correlation error from 0 dB to 20 dB SNR.

preamble_list = {'period2', 'zadoff_chu', 'barker', 'pn'};
snr_vec       = 0 : 2 : 20;
N_trials      = 40;
N_win         = cfg.coarse.win_len;
true_cfo      = 0.085;
rms_err_pct   = zeros(numel(preamble_list), numel(snr_vec));

for p = 1:numel(preamble_list)
    p_syms = generate_preamble(preamble_list{p}, N_win);
    for s = 1:numel(snr_vec)
        errs = zeros(N_trials, 1);
        for t = 1:N_trials
            n = (0:N_win-1).';
            rx_rot = p_syms .* exp(1j * (2*pi*true_cfo*n + rand()*2*pi));
            noise_pwr = mean(abs(rx_rot).^2) / (10^(snr_vec(s)/10));
            rx_noisy  = rx_rot + sqrt(noise_pwr/2)*(randn(N_win,1) + 1j*randn(N_win,1));
            [cfo_est, ~] = run_coarse_cfo_subsystem(rx_noisy, cfg, p_syms);
            errs(t) = 100 * (cfo_est - true_cfo);
        end
        rms_err_pct(p, s) = sqrt(mean(errs.^2));
    end
end

figure('Color', 'w', 'Name', 'CP3: Preamble & Coarse CFO Benchmark');
semilogy(snr_vec, rms_err_pct, '-o', 'LineWidth', 1.6); hold on;
yline(0.5, 'r--', 'LineWidth', 1.8, 'DisplayName', 'CP3 Limit (0.5% R_{sym})');
grid on; xlabel('SNR (dB)'); ylabel('RMS Coarse CFO Error (% of R_{sym})');
title(sprintf('Coarse CFO Accuracy (Lags 2 & 8, Window = %d Symbols)', N_win));
legend([preamble_list, {'CP3 Limit (0.5%)'}], 'Location', 'northeast');
