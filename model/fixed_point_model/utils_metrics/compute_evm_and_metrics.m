function metrics = compute_evm_and_metrics(rx_out, tx_payload, cfg, measured_esn0_dB)
    % Part 0f & Part 2 (2a, 2b, 2c, 2d):
    % - Synchroniser output y_k and transmitted reference s_k are on the same (peak-normalised) scale.
    % - Aligns output symbols with transmitted payload over >= 1000 symbols after lock.
    % - Computes both RMS-referenced and Peak-referenced EVM from actual transmitted symbols s_k,
    %   along with measured noise-floor EVM = 10^(-EsN0/20)*100 and excess EVM = sqrt(measured^2 - floor^2).

    tx_payload = tx_payload(:);
    y_all = rx_out.out_sym_cplx(:);     % output is on the same (peak-normalised) scale as tx_payload

    N_total = numel(y_all);
    N_pay   = numel(tx_payload);
    N_pre   = cfg.N_preamble;

    best_corr = -1;
    best_lag  = 0;
    for lag = -8:8
        i0 = max(1, 1 - (N_pre + lag));
        i1 = min(N_pay, N_total - N_pre - lag);
        if (i1 - i0) < 200, continue; end
        seg   = y_all(N_pre + lag + (i0:i1));
        c_val = abs(seg' * tx_payload(i0:i1)) / sqrt(i1 - i0 + 1);
        if c_val > best_corr
            best_corr = c_val;
            best_lag  = lag;
        end
    end

    i0          = max(1, 1 - (N_pre + best_lag));
    i1          = min(N_pay, max(1, N_total - N_pre - best_lag));
    overlap_len = max(1, i1 - i0 + 1);
    n_eval      = min(1000, min(overlap_len, min(numel(tx_payload), numel(y_all))));
    n_eval      = max(1, n_eval);

    start_idx = max(1, i1 - n_eval + 1);
    end_idx   = min(numel(tx_payload), start_idx + n_eval - 1);
    pay_idx   = start_idx : end_idx;

    idx_eval  = N_pre + best_lag + pay_idx;
    idx_eval  = max(1, min(numel(y_all), idx_eval));
    n_eval    = min(numel(pay_idx), numel(idx_eval));

    s_k       = tx_payload(pay_idx(1:n_eval));
    y_k       = y_all(idx_eval(1:n_eval));

    % Part 2b & 2c: e_k = y_k - s_k with denominators from actual transmitted symbols s_k
    e_k    = y_k - s_k;
    rms_e  = sqrt(mean(abs(e_k).^2));
    rms_s  = sqrt(mean(abs(s_k).^2));
    peak_s = max(abs(s_k));

    metrics.evm_rms_pct  = 100 * (rms_e / rms_s);
    metrics.evm_peak_pct = 100 * (rms_e / peak_s);
    metrics.payload_lag  = best_lag;
    metrics.n_eval       = n_eval;

    % Part 2a: Noise-floor EVM and Excess EVM
    if exist('measured_esn0_dB', 'var') == 0
        if isfield(cfg, 'snr_def') && strcmpi(cfg.snr_def, 'sample')
            measured_esn0_dB = cfg.snr_dB + 10 * log10(cfg.sps);
        else
            measured_esn0_dB = cfg.snr_dB;
        end
    end
    metrics.measured_esn0_dB = measured_esn0_dB;

    if isfinite(measured_esn0_dB)
        metrics.floor_rms_pct = 100 * (10^(-measured_esn0_dB / 20));
    else
        metrics.floor_rms_pct = 0.0;
    end
    metrics.excess_rms_pct  = sqrt(max(metrics.evm_rms_pct^2 - metrics.floor_rms_pct^2, 0.0));
    metrics.floor_peak_pct  = metrics.floor_rms_pct * (rms_s / peak_s);
    metrics.excess_peak_pct = sqrt(max(metrics.evm_peak_pct^2 - metrics.floor_peak_pct^2, 0.0));

    norm_mode = 'peak';
    if isfield(cfg, 'norm_mode')
        norm_mode = cfg.norm_mode;
    end

    dec_eval = zeros(n_eval, 1);
    for k = 1:n_eval
        dec_eval(k) = qam_slicer(y_k(k), cfg.mod_type, norm_mode);
    end
    metrics.ser        = mean(abs(dec_eval - s_k) > 1e-4);
    metrics.evm_dd_pct = 100 * (sqrt(mean(abs(y_k - dec_eval).^2)) / rms_s);

    n_k        = (rx_out.str.sym_clk_idx(idx_eval) - 3) + rx_out.str.mu_log(idx_eval);
    theta_true = 2 * pi * (cfg.cfo_norm / cfg.sps) * n_k + cfg.phase_offset;
    theta_nco  = rx_out.nco_phase_log(idx_eval);

    ph_diff_rad  = angle(exp(1j * (theta_nco - theta_true)));
    bias_rad     = angle(mean(exp(1j * ph_diff_rad)));
    centered_rad = angle(exp(1j * (ph_diff_rad - bias_rad)));

    metrics.phase_bias_deg    = bias_rad * (180 / pi);
    metrics.phase_err_deg_rms = sqrt(mean(centered_rad.^2)) * (180 / pi);

    t_tail                     = rx_out.str.t_phase_log(idx_eval);
    metrics.timing_jitter_Ts   = std(t_tail);
    metrics.coarse_cfo_err_pct = 100 * abs(rx_out.coarse_cfo_est - cfg.cfo_norm);
    metrics.fine_cfo_err_pct   = 100 * abs(rx_out.fine_cfo_est   - cfg.cfo_norm);

    metrics.str_lock_syms = -1;
    if ~isnan(rx_out.str_lock_sym), metrics.str_lock_syms = round(rx_out.str_lock_sym); end

    metrics.costas_lock_syms           = -1;
    metrics.costas_lock_from_load_syms = -1;
    if ~isnan(rx_out.costas_lock_sym)
        metrics.costas_lock_syms           = round(rx_out.costas_lock_sym);
        metrics.costas_lock_from_load_syms = round(rx_out.costas_lock_from_load);
    end

    if ~isfinite(cfg.snr_dB) || cfg.snr_dB >= 40
        evm_limit = 2.5;
    elseif cfg.mod_type == 0
        evm_limit = 5.5;
    else
        evm_limit = 8.0;
    end
    metrics.evm_target_pct        = evm_limit;
    metrics.pass.evm_rms          = (metrics.excess_rms_pct  <= evm_limit);
    metrics.pass.evm_peak         = (metrics.excess_peak_pct <= evm_limit);
    metrics.pass.evm              = metrics.pass.evm_rms;
    metrics.pass.str_jitter       = (metrics.timing_jitter_Ts <= 0.02);
    metrics.pass.str_lock         = (metrics.str_lock_syms > 0) && (metrics.str_lock_syms <= 150);
    metrics.pass.coarse_cfo       = (metrics.coarse_cfo_err_pct <= 0.5);
    metrics.pass.coarse_latency   = (cfg.coarse.win_len >= 32) && (cfg.coarse.win_len <= 128);
    metrics.pass.fine_cfo         = (metrics.fine_cfo_err_pct <= 1.0);
    metrics.pass.phase_err        = (metrics.phase_err_deg_rms <= 1.5);
    metrics.pass.costas_lock_load = (metrics.costas_lock_from_load_syms > 0) && (metrics.costas_lock_from_load_syms <= 200);
    metrics.pass.costas_lock_tot  = (metrics.costas_lock_syms > 0) && (metrics.costas_lock_syms <= 200);
    metrics.pass.quad_resolved    = (~rx_out.quad_unresolved) && (abs(metrics.phase_bias_deg) < 15.0);
end
