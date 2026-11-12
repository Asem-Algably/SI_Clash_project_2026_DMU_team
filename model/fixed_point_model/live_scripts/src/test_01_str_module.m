%% Isolated Component Test 01: Symbol Timing Recovery (CP2)
% Evaluates the Parabolic Farrow interpolator via Horner's Rule,
% Modulo-1 controller, and Gardner TED across fractional delays tau in [0, 1).

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

%% 1. Measure Open-Loop Gardner TED S-Curve (Parabolic Farrow)
% Sweep timing offset from -0.5 Ts to +0.5 Ts with loop step forced to W = 0.25.

tau_sweep = linspace(-0.5, 0.5, 41);
s_curve   = zeros(size(tau_sweep));
syms_test = generate_preamble('q4q2_q1', 400, cfg);
tx_sig    = pulse_shape_rrc(syms_test, cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');

for i = 1:numel(tau_sweep)
    cfg_s = cfg; cfg_s.tau_offset = tau_sweep(i); cfg_s.cfo_norm = 0; cfg_s.snr_dB = Inf;
    rx_s  = apply_channel_impairments(tx_sig, cfg_s);
    cfg_s.str.open_loop = true;
    res_s = run_str_subsystem(rx_s, cfg_s);
    s_curve(i) = mean(res_s.ted_log(50:end));
end

figure('Color', 'w', 'Name', 'CP2: Gardner S-Curve & Parabolic Farrow Tracking');
subplot(1,2,1);
plot(tau_sweep, s_curve, 'b-o', 'LineWidth', 1.5); grid on;
xlabel('Timing Offset \tau (T_s)'); ylabel('Mean Gardner TED Output');
title('Open-Loop Gardner TED S-Curve (Parabolic Farrow)');

%% 2. Evaluate Parabolic Farrow Across Fractional Delay (0 <= tau < 1)
% Verify that residual timing jitter stays below 0.02 Ts across all delays (R.111).

taus    = 0 : 0.1 : 0.9;
jitters = zeros(1, numel(taus));
syms_q  = generate_payload(0, 800, 7);
tx_q    = pulse_shape_rrc(syms_q, cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');

for i = 1:numel(taus)
    cfg_t = cfg;
    cfg_t.str.interp_type = 'parabolic';
    cfg_t.tau_offset      = taus(i);
    cfg_t.snr_dB          = 15.0;
    cfg_t.cfo_norm        = 0.10;
    rx_t  = apply_channel_impairments(tx_q, cfg_t);
    res_t = run_str_subsystem(rx_t, cfg_t);
    jitters(i) = std(res_t.t_phase_log(250:end));
end

subplot(1,2,2);
plot(taus, jitters, 'r-s', 'LineWidth', 1.5, 'DisplayName', 'Parabolic Farrow'); hold on;
yline(0.02, 'k:', 'LineWidth', 1.5, 'DisplayName', 'R.111 Limit (0.02 T_s)'); grid on;
ylim([0 0.03]);
xlabel('Injected Fractional Delay \tau (T_s)'); ylabel('Residual Timing Jitter (T_s RMS)');
title('STR Jitter vs. \tau @ SNR = 15 dB, CFO = 0.10 R_{sym}');
legend('Location', 'best');
