%% Si-CLASH Master Synchronizer Live Explorer (Pure Cycle-Accurate Fixed-Point)
% Runs the complete end-to-end Transmitter, Physical Channel / ADC Front-End,
% and Blind Three-Stage Cycle-Accurate Fixed-Point Receiver Synchronization pipeline.

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

%% 1. Configure Full-Burst Simulation (QPSK or 16-QAM)
cfg = get_default_config();
cfg.mod_type        = 1;             % 0 = QPSK, 1 = 16-QAM
cfg.norm_mode       = 'peak';        % 'peak' (default) or 'rms'
cfg.snr_def         = 'sample';      % 'sample' (default) or 'esn0'
cfg.str.interp_type = 'parabolic';   % Parabolic Farrow interpolator
cfg.snr_dB          = 18.0;          % Requested SNR (dB)
cfg.tau_offset      = 0.35;          % Fractional timing skew in Ts
cfg.cfo_norm        = 0.065;         % +6.5% Rsym Carrier Frequency Offset
cfg.phase_offset    = 115*(pi/180);  % Arbitrary initial carrier phase (tests quadrant recovery)
cfg.preamble_type   = 'q4q2_q1';     % Three-phase blind preamble [Q1, Q2, Q4, Q1]

%% 2. Generate Burst Frame, RRC Pulse Shaping & Channel / ADC Front-End (/2 & Q1.11 Clip)
preamble_syms = generate_preamble(cfg.preamble_type, cfg.N_preamble, cfg);
[payload_syms, const] = generate_payload(cfg.mod_type, cfg.N_payload, cfg.seed, cfg.norm_mode);
tx_syms     = [preamble_syms; payload_syms];
tx_waveform = pulse_shape_rrc(tx_syms, cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
meas_esn0   = measure_es_n0(tx_waveform, cfg);

% apply_channel_impairments applies /2 scaling (in_scale = 0.5) and Q1.11 ADC clipping [-1, 1 - 2^-11]
[rx_in_q11, ch_info] = apply_channel_impairments(tx_waveform, cfg);
in_valid = true(size(rx_in_q11));

%% 3. Run Cycle-Accurate Fixed-Point Synchronizer & Print Specification Report
rx_out  = run_cycle_accurate_top(rx_in_q11, in_valid, cfg);
metrics = compute_evm_and_metrics(rx_out, payload_syms, cfg, meas_esn0);

print_spec_report(rx_out, metrics, cfg, ch_info);
plot_sync_diagnostics(rx_out, metrics, cfg);
