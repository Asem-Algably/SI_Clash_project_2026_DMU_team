%% export_test_vectors.m
% Copyright lowRISC contributors.
% Licensed under the Apache License, Version 2.0, see LICENSE for details.
% SPDX-License-Identifier: Apache-2.0
%
% Run the golden model and export test vectors for the RTL testbenches.
%
% Robust: searches for the helper .m files in:
%   (a) subfolders (config/, tx_channel/, rx_blocks/, utils_metrics/)
%   (b) the same folder as this script (flat structure)
%
% Output: <script_dir>/generated/vectors/

function export_test_vectors(out_dir)
    % ---------------------------------------------------------------
    % 1. Locate script directory
    % ---------------------------------------------------------------
    this_dir = fileparts(mfilename('fullpath'));

    % ---------------------------------------------------------------
    % 2. Ensure required .m files are on the MATLAB path
    % ---------------------------------------------------------------
    required_files = { ...
        'get_hw_config.m', ...
        'generate_frame.m', ...
        'run_cycle_accurate_top.m', ...
        'compute_evm_and_metrics.m'};

    % Candidate folders (subfolder first, parent folder, then flat)
    search_roots = { ...
        fullfile(this_dir, '..', 'config'), ...
        fullfile(this_dir, '..', 'tx_channel'), ...
        fullfile(this_dir, '..', 'rx_blocks'), ...
        fullfile(this_dir, '..', 'utils_metrics'), ...
        fullfile(this_dir, 'config'), ...
        fullfile(this_dir, 'tx_channel'), ...
        fullfile(this_dir, 'rx_blocks'), ...
        fullfile(this_dir, 'utils_metrics'), ...
        this_dir};

    % Add all existing ones to path
    for k = 1:numel(search_roots)
        if exist(search_roots{k}, 'dir')
            addpath(search_roots{k});
        end
    end

    % Verify every required file is reachable
    missing = {};
    for k = 1:numel(required_files)
        if exist(required_files{k}, 'file') ~= 2
            missing{end+1} = required_files{k};   %#ok<AGROW>
        end
    end

    if ~isempty(missing)
        fprintf('\n[ERROR] Cannot find these .m files on the MATLAB path:\n');
        for k = 1:numel(missing)
            fprintf('   - %s\n', missing{k});
        end
        fprintf('\nSearched in:\n');
        for k = 1:numel(search_roots)
            if exist(search_roots{k}, 'dir') == 7
                marker = '';
            else
                marker = '  (missing)';
            end
            fprintf('   %s%s\n', search_roots{k}, marker);
        end
        fprintf('\n[FIX] Make sure all golden-model .m files are either\n');
        fprintf('  (a) in subfolders: config/, tx_channel/, rx_blocks/, utils_metrics/\n');
        fprintf('  (b) OR all in the same folder as this script:\n');
        fprintf('      %s\n\n', this_dir);
        error('Missing golden-model files');
    end

    % ---------------------------------------------------------------
    % 3. Output folder: <this_dir>/generated/vectors/
    % ---------------------------------------------------------------
    if nargin < 1 || isempty(out_dir)
        out_dir = fullfile(this_dir, 'generated', 'vectors');
    end
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
        fprintf('[OK] Created: %s\n', out_dir);
    end

    % ---------------------------------------------------------------
    % 4. Generate frame + run golden model
    % ---------------------------------------------------------------
    fprintf('\n=== Export Test Vectors ===\n\n');

    cfg = get_hw_config();

    fprintf('[1/3] Generating frame...\n');
    [rx_samples_fi, tx_payload_fi, ~] = generate_frame(cfg);

    fprintf('[2/3] Running golden model (cycle-accurate)...\n');
    t0 = tic;
    [rx_out, ~] = run_cycle_accurate_top(rx_samples_fi, ...
                                          true(size(rx_samples_fi)), cfg);
    fprintf('      Done in %.1f seconds\n', toc(t0));

    metrics = compute_evm_and_metrics(rx_out, tx_payload_fi, cfg);

    % ---------------------------------------------------------------
    % 5. Write .hex files (properly quantized to stored integer values)
    % ---------------------------------------------------------------
    fprintf('[3/3] Writing vectors to %s\n', out_dir);

    % Input samples: Q1.11 (12-bit signed, 11 fractional bits)
    write_hex(fullfile(out_dir, 'preamble_i.hex'), ...
              double(storedInteger(real(rx_samples_fi))), 12);
    write_hex(fullfile(out_dir, 'preamble_q.hex'), ...
              double(storedInteger(imag(rx_samples_fi))), 12);

    % Expected RTL output: Q1.15 (16-bit signed, 15 fractional bits)
    % GM internally uses sQ1.14 -> stored integer has 14 frac bits, multiply by 2 for Q1.15
    write_hex(fullfile(out_dir, 'expected_out_i.hex'), ...
              2 * double(storedInteger(rx_out.out_sym_i)), 16);
    write_hex(fullfile(out_dir, 'expected_out_q.hex'), ...
              2 * double(storedInteger(rx_out.out_sym_q)), 16);

    % Ideal physical symbols: Q1.15 (for EVM reference)
    % tx_payload_fi has 14 frac bits -> multiply by 2 for Q1.15
    write_hex(fullfile(out_dir, 'expected_ideal_i.hex'), ...
              2 * double(storedInteger(real(tx_payload_fi))), 16);
    write_hex(fullfile(out_dir, 'expected_ideal_q.hex'), ...
              2 * double(storedInteger(imag(tx_payload_fi))), 16);

    % ---------------------------------------------------------------
    % 6. Write metrics file (text)
    % ---------------------------------------------------------------
    fid = fopen(fullfile(out_dir, 'expected_metrics.txt'), 'w');
    assert(fid > 0, 'Cannot open expected_metrics.txt');
    fprintf(fid, 'N_preamble        = %d\n', cfg.N_preamble);
    fprintf(fid, 'N_payload         = %d\n', cfg.N_payload);
    fprintf(fid, 'mod_type          = %d\n', cfg.mod_type);
    fprintf(fid, 'coarse_cfo_stored = %d\n', ...
            int32(storedInteger(rx_out.coarse_cfo_est)));
    fprintf(fid, 'str_lock_sym      = %d\n', round(rx_out.str_lock_sym));
    fprintf(fid, 'costas_lock_sym   = %d\n', round(rx_out.costas_lock_sym));
    fprintf(fid, 'quad_k            = %d\n', round(rx_out.quad_k));
    fprintf(fid, 'quad_unresolved   = %d\n', rx_out.quad_unresolved);
    fprintf(fid, 'excess_evm_pct    = %.4f\n', double(metrics.evm_excess_pct));
    fprintf(fid, 'total_evm_pct     = %.4f\n', double(metrics.evm_total_pct));
    fprintf(fid, 'ser               = %.6f\n', double(metrics.ser));
    fclose(fid);

    % ---------------------------------------------------------------
    % 7. Summary
    % ---------------------------------------------------------------
    fprintf('\n==========================================================\n');
    fprintf('  DONE\n');
    fprintf('==========================================================\n');
    fprintf('  Excess EVM     : %8.4f %%\n', double(metrics.evm_excess_pct));
    fprintf('  Total EVM      : %8.4f %%\n', double(metrics.evm_total_pct));
    fprintf('  SER            : %8.6f\n',    double(metrics.ser));
    fprintf('  STR lock sym   : %8d\n',      round(rx_out.str_lock_sym));
    fprintf('  Costas lock sym: %8d\n',      round(rx_out.costas_lock_sym));
    fprintf('  Quad k         : %8d (unres=%d)\n', ...
            round(rx_out.quad_k), rx_out.quad_unresolved);
    fprintf('\nFiles written to:\n  %s\n\n', out_dir);
    fprintf('  preamble_i.hex        (%d samples, Q1.11)\n', numel(rx_samples_fi));
    fprintf('  preamble_q.hex        (%d samples, Q1.11)\n', numel(rx_samples_fi));
    fprintf('  expected_out_i.hex    (%d symbols, Q1.15)\n', numel(rx_out.out_sym_i));
    fprintf('  expected_out_q.hex    (%d symbols, Q1.15)\n', numel(rx_out.out_sym_i));
    fprintf('  expected_ideal_i.hex  (%d symbols, Q1.15)\n', numel(tx_payload_fi));
    fprintf('  expected_ideal_q.hex  (%d symbols, Q1.15)\n', numel(tx_payload_fi));
    fprintf('  expected_metrics.txt\n');
    fprintf('\nNext: copy these files to <your_tb>/vectors/\n');
    fprintf('==========================================================\n\n');
end

% =========================================================================
% Helper: write signed integer data as hex (two's complement)
% =========================================================================
function write_hex(path, data, bits)
    fid = fopen(path, 'w');
    assert(fid > 0, 'Cannot open %s', path);

    max_val = 2^(bits-1) - 1;
    min_val = -2^(bits-1);
    digits  = ceil(bits / 4);
    fmt     = sprintf('%%0%dx\n', digits);

    for k = 1:numel(data)
        v = round(double(data(k)));
        v = max(min_val, min(max_val, v));
        if v < 0
            v = v + 2^bits;
        end
        fprintf(fid, fmt, v);
    end
    fclose(fid);
end