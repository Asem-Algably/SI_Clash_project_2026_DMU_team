% RUN_SIM  Master Top-Level Execution Script for Fixed-Point Golden Model.
%
% Generates a burst frame (190-sym preamble + 1200-sym payload), runs through the
% cycle-accurate fixed-point synchronizer, and prints performance metrics.

clear; clc;
addpath('config');
addpath('tx_channel');
addpath('rx_blocks');
addpath('utils_metrics');
fprintf('=== Fixed-Point Golden Model Synchronizer Simulation ===\n\n');

% 1. Load Hardware Configuration
cfg = get_hw_config();

% 2. Generate Frame & Apply Channel Impairments
fprintf('[1/3] Generating frame (190 preamble + %d payload symbols)...\n', cfg.N_payload);
[rx_samples, tx_payload, frame_info] = generate_frame(cfg);

% 3. Run Cycle-Accurate Synchronizer Loop
fprintf('[2/3] Executing cycle-accurate synchronizer loop (%d samples)...\n', numel(rx_samples));
t_start = tic;
[rx_out, lg] = run_cycle_accurate_top(rx_samples, true(size(rx_samples)), cfg);
t_elapsed = toc(t_start);
fprintf('      Simulation finished in %.2f seconds.\n', t_elapsed);

% 4. Compute Performance Metrics
fprintf('[3/3] Scoring metrics on payload post-lock...\n\n');
metrics = compute_evm_and_metrics(rx_out, tx_payload, cfg);

% 5. Print Formatted Report
fprintf('------------------------------------------------------------\n');
fprintf('  SYNCHRONIZER PERFORMANCE REPORT\n');
fprintf('------------------------------------------------------------\n');
fprintf('  PRIMARY METRIC - Excess EVM : %8.4f %%\n', double(metrics.evm_excess_pct));
fprintf('  Total EVM (RMS)             : %8.4f %%\n', double(metrics.evm_total_pct));
fprintf('  Floor EVM (Es/N0=%.2fdB)   : %8.4f %%\n', metrics.esn0_dB, double(metrics.evm_floor_pct));
fprintf('  Symbol Error Rate (SER)     : %8.4f\n', double(metrics.ser));
fprintf('  STR Timing Jitter (RMS)     : %8.4f Ts (Target: <= 0.0200)\n', metrics.timing_jitter_Ts);
fprintf('  STR Lock Symbol             : %8.0f\n', double(metrics.str_lock_sym));
fprintf('  Coarse CFO Done Symbol      : %8.0f\n', double(rx_out.coarse_done_sym));
fprintf('  Costas Public Lock Symbol   : %8.0f\n', double(metrics.costas_lock_sym));
fprintf('  Quadrant Ambiguity k        : %8.0f (unres=%d)\n', double(rx_out.quad_k), rx_out.quad_unresolved);
fprintf('  Coarse CFO Estimate (turns) : %+8.5f (True: %+8.5f)\n', double(rx_out.coarse_cfo_est), cfg.cfo_norm);
fprintf('  Fine CFO Estimate (turns)   : %+8.5f (Error: %8.5f)\n', double(rx_out.fine_cfo_est), metrics.fine_cfo_err);
fprintf('  Evaluated Payload Symbols   : %8d\n', metrics.n_eval);
fprintf('------------------------------------------------------------\n');
if double(metrics.ser) == 0 && double(metrics.evm_excess_pct) < 10.0
    fprintf('  STATUS: >>> PASSED ALL SPECIFICATIONS <<<\n');
else
    fprintf('  STATUS: >>> FAILED SPECIFICATIONS <<<\n');
end
fprintf('------------------------------------------------------------\n');

% 6. Optional Diagnostic Plot (if interactive display available)
if usejava('jvm') && usejava('awt') && ~batchStartupOptionUsed
    plot_sync_diagnostics(rx_out, metrics, cfg);
end
