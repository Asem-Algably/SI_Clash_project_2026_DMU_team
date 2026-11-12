function print_spec_report(rx_out, metrics, cfg, ch_info)
    % PRINT_SPEC_REPORT  Format and display synchronization verification report.
    % Evaluates all project performance metrics against SI-CLASH competition specifications:
    %   - EVM compliance (clean <= 2.5%, QPSK <= 5.5%, 16-QAM <= 8.0%)
    %   - Timing jitter <= 0.02 Ts (R.111) and STR lock time <= 150 syms (R.112)
    %   - Coarse CFO accuracy <= 0.5% (CP3) and latency 32..128 syms (R.116)
    %   - Residual CFO <= 0.01 Rsym (R.117) and phase error <= 1.5 deg RMS (R.121)
    %   - Costas lock acquisition <= 200 syms (R.122)

    const = get_constellation_map(cfg.mod_type, cfg.norm_mode);
    snr_def = 'esn0';
    if isfield(cfg, 'snr_def'), snr_def = cfg.snr_def; end

    disp(repmat('=', 1, 104));
    disp(sprintf('  Si-CLASH SYNCHRONIZATION UNIT SPECIFICATION REPORT (%s, norm_mode=''%s'', snr_def=''%s'', Req SNR=%.1f dB, Meas Es/N0=%.2f dB)', ...
        const.name, cfg.norm_mode, snr_def, cfg.snr_dB, metrics.measured_esn0_dB));
    disp(repmat('=', 1, 104));
    disp(sprintf('  %-44s | %-34s | %-12s | %-6s', 'Specification / Definition', 'Measured Value', 'Target Limit', 'Status'));
    disp(repmat('-', 1, 104));

    % 1. Part 2a..2d: Dual-normalisation EVM rows (RMS-ref and Peak-ref)
    lbl_rms  = sprintf('EVM (RMS-ref,  snr_def=%s, norm=%s)', snr_def, cfg.norm_mode);
    val_rms  = sprintf('Meas=%.2f%%, Flr=%.2f%%, Exc=%.2f%%', metrics.evm_rms_pct, metrics.floor_rms_pct, metrics.excess_rms_pct);
    disp(sprintf('  %-44s | %-34s | <= %6.2f %%  | [%s]', lbl_rms, val_rms, metrics.evm_target_pct, pf_str(metrics.pass.evm_rms)));

    lbl_peak = sprintf('EVM (Peak-ref, snr_def=%s, norm=%s)', snr_def, cfg.norm_mode);
    val_peak = sprintf('Meas=%.2f%%, Flr=%.2f%%, Exc=%.2f%%', metrics.evm_peak_pct, metrics.floor_peak_pct, metrics.excess_peak_pct);
    disp(sprintf('  %-44s | %-34s | <= %6.2f %%  | [%s]', lbl_peak, val_peak, metrics.evm_target_pct, pf_str(metrics.pass.evm_peak)));

    % 2. R.111 STR Timing Jitter
    disp(sprintf('  %-44s | %31.4f Ts | <= %6.4f Ts | [%s]', ...
        'STR Timing Jitter RMS (R.111)', metrics.timing_jitter_Ts, 0.0200, pf_str(metrics.pass.str_jitter)));

    % 3. R.112 STR Lock Acquisition Time
    disp(sprintf('  %-44s | %30d sym | <= %6d sym | [%s]', ...
        'STR Lock Time (R.112)', metrics.str_lock_syms, 150, pf_str(metrics.pass.str_lock)));

    % 4. CP3 Coarse CFO Accuracy
    disp(sprintf('  %-44s | %31.4f %%  | <= %6.3f %%  | [%s]', ...
        'Coarse CFO Error (CP3)', metrics.coarse_cfo_err_pct, 0.500, pf_str(metrics.pass.coarse_cfo)));

    % 5. R.116 Coarse CFO Latency
    disp(sprintf('  %-44s | %30d sym | 32 .. 128 sym| [%s]', ...
        'Coarse CFO Window Latency (R.116)', cfg.coarse.win_len, pf_str(metrics.pass.coarse_latency)));

    % 6. R.117 Fine Residual CFO
    disp(sprintf('  %-44s | %31.4f %%  | <= %6.3f %%  | [%s]', ...
        'Fine Residual CFO Error (R.117)', metrics.fine_cfo_err_pct, 1.000, pf_str(metrics.pass.fine_cfo)));

    % 7. R.121 Residual Carrier Phase Error
    disp(sprintf('  %-44s | %30.2f deg | <= %6.2f deg| [%s]', ...
        'Residual Phase Error RMS (R.121)', metrics.phase_err_deg_rms, 1.50, pf_str(metrics.pass.phase_err)));

    % 8. R.122 Fine Lock Acquisition Time (from LOAD & from Burst Start)
    disp(sprintf('  %-44s | %30d sym | <= %6d sym | [%s]', ...
        'Costas Lock from LOAD (R.122)', metrics.costas_lock_from_load_syms, 200, pf_str(metrics.pass.costas_lock_load)));
    disp(sprintf('  %-44s | %30d sym | <= %6d sym | [%s]', ...
        'Costas Lock from Burst Start', metrics.costas_lock_syms, 200, pf_str(metrics.pass.costas_lock_tot)));

    % 9. Quadrant Ambiguity & SER Check
    disp(sprintf('  %-44s | Bias=%+6.2f deg, Unresolved=%d       | Unres == 0   | [%s]', ...
        'Quadrant Ambiguity Check', metrics.phase_bias_deg, double(rx_out.quad_unresolved), pf_str(metrics.pass.quad_resolved)));
    disp(sprintf('  %-44s | %34.4f | <= %6.4f    | [%s]', ...
        'Payload Symbol Error Rate (SER)', metrics.ser, 0.0100, pf_str(metrics.ser <= 0.01)));

    % 10. Part 0c, 0f, 4b: Hardware Clip & Saturation Safety Counters
    q11_c = 0;
    if isfield(rx_out, 'q11_clip_count')
        q11_c = rx_out.q11_clip_count;
    end
    q15_c = 0; if isfield(rx_out, 'q15_clip_count'), q15_c = rx_out.q15_clip_count; end
    sat_s = 0; if isfield(rx_out, 'str_sat_count'),  sat_s = rx_out.str_sat_count;  end
    sat_c = 0; if isfield(rx_out, 'costas_sat_count'), sat_c = rx_out.costas_sat_count; end
    hw_str = sprintf('Q11=%d, Q15=%d, STR_sat=%d, Cos_sat=%d', q11_c, q15_c, sat_s, sat_c);
    disp(sprintf('  %-44s | %-34s | All == 0     | [%s]', ...
        'Hardware Clip & Saturation Counters (0c,4b)', hw_str, pf_str((q11_c + q15_c + sat_s + sat_c) == 0)));
    disp(repmat('=', 1, 104));
end

function s = pf_str(flag)
    if flag
        s = 'PASS';
    else
        s = 'FAIL';
    end
end
