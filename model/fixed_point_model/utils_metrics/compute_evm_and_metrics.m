function metrics = compute_evm_and_metrics(rx_out, tx_payload, cfg, measured_esn0_dB)
    % Part 0f & Part 2 (2a, 2b, 2c, 2d):
    % - Synchroniser output y_k and transmitted reference s_k are on the same (peak-normalised) scale.
    % - Aligns output symbols with transmitted payload over >= 1000 symbols after lock.
    % - Computes both RMS-referenced and Peak-referenced EVM from actual transmitted symbols s_k,
    %   along with measured noise-floor EVM = 10^(-EsN0/20)*100 and excess EVM = sqrt(measured^2 - floor^2).

    tx_payload = tx_payload(:);
    y_raw = rx_out.out_sym_cplx(:);

    % Outer system scales back by multiplying by 2 (reversing front-end /2 ADC scaling)
    if isfield(cfg, 'in_scale') && (cfg.in_scale > 0)
        y_all = fi(y_raw / cfg.in_scale, 1, 16, 14);
    else
        y_all = fi(2.0 * y_raw, 1, 16, 14);
    end

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

    % Output is compared strictly after lock acquisition is declared
    lock_sym_idx = N_pre + best_lag + 1;
    if isfield(rx_out, 'costas_lock_sym') && ~isnan(rx_out.costas_lock_sym) && (rx_out.costas_lock_sym > 0)
        lock_sym_idx = max(lock_sym_idx, rx_out.costas_lock_sym);
    elseif isfield(rx_out, 'lock_detect') && any(rx_out.lock_detect)
        first_ld = find(rx_out.lock_detect, 1, 'first');
        lock_sym_idx = max(lock_sym_idx, first_ld);
    end

    start_pay_idx = max(1, lock_sym_idx - (N_pre + best_lag));
    if start_pay_idx <= N_pay
        avail_len = N_pay - start_pay_idx + 1;
        n_eval    = min(1000, min(avail_len, max(0, N_total - (N_pre + best_lag + start_pay_idx - 1))));
        if n_eval > 10
            pay_idx  = start_pay_idx : (start_pay_idx + n_eval - 1);
        else
            i0       = max(1, 1 - (N_pre + best_lag));
            i1       = min(N_pay, N_total - N_pre - best_lag);
            if i1 >= i0
                n_eval   = min(1000, i1 - i0 + 1);
                pay_idx  = (i1 - n_eval + 1) : i1;
            else
                pay_idx  = [];
            end
        end
    else
        i0       = max(1, 1 - (N_pre + best_lag));
        i1       = min(N_pay, N_total - N_pre - best_lag);
        if i1 >= i0
            n_eval   = min(1000, i1 - i0 + 1);
            pay_idx  = (i1 - n_eval + 1) : i1;
        else
            pay_idx  = [];
        end
    end

    idx_eval = N_pre + best_lag + pay_idx;
    valid_mask = (idx_eval >= 1) & (idx_eval <= N_total) & (pay_idx >= 1) & (pay_idx <= N_pay);
    pay_idx  = pay_idx(valid_mask);
    idx_eval = idx_eval(valid_mask);

    if isempty(idx_eval)
        n_fb = min([50, N_total, N_pay]);
        if n_fb > 0
            idx_eval = (N_total - n_fb + 1) : N_total;
            pay_idx  = (N_pay - n_fb + 1) : N_pay;
        else
            idx_eval = 1:min(N_total, N_pay);
            pay_idx  = 1:min(N_total, N_pay);
        end
    end
    n_eval = numel(pay_idx);
    s_k = tx_payload(pay_idx);
    y_k = y_all(idx_eval);

    % Part 2b & 2c: Fixed-point EVM computation using 32-bit error accumulator and fi square root
    e_k   = y_k - s_k; % pure fi subtraction
    e_re  = real(e_k);
    e_im  = imag(e_k);
    e_sq  = e_re .* e_re + e_im .* e_im;
    sum_e = sum(fi(e_sq, 0, 32, 28));
    mean_e = sum_e / n_eval;
    rms_e = sqrt(fi(mean_e, 0, 32, 28));

    s_re  = real(s_k);
    s_im  = imag(s_k);
    s_sq  = s_re .* s_re + s_im .* s_im;
    sum_s = sum(fi(s_sq, 0, 32, 28));
    mean_s = sum_s / n_eval;
    rms_s = sqrt(fi(mean_s, 0, 32, 28));
    peak_s = sqrt(double(max(s_sq)));

    % 16-bit Q8.8 fixed-point EVM percentages
    metrics.evm_rms_pct  = fi((double(rms_e) / double(rms_s)) * 100, 0, 16, 8);
    metrics.evm_peak_pct = fi((double(rms_e) / peak_s) * 100, 0, 16, 8);
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
        metrics.floor_rms_pct = fi(100 * (10^(-measured_esn0_dB / 20)), 0, 16, 8);
    else
        metrics.floor_rms_pct = fi(0.0, 0, 16, 8);
    end
    d_evm_rms   = double(metrics.evm_rms_pct);
    d_floor_rms = double(metrics.floor_rms_pct);
    metrics.excess_rms_pct  = sqrt(max(d_evm_rms^2 - d_floor_rms^2, 0.0));
    metrics.floor_peak_pct  = double(metrics.floor_rms_pct) * (double(rms_s) / double(peak_s));
    d_evm_peak  = double(metrics.evm_peak_pct);
    metrics.excess_peak_pct = sqrt(max(d_evm_peak^2 - metrics.floor_peak_pct^2, 0.0));

    norm_mode = 'peak';
    if isfield(cfg, 'norm_mode')
        norm_mode = cfg.norm_mode;
    end

    dec_eval = complex(zeros(n_eval, 1));
    for k = 1:n_eval
        dec_eval(k) = qam_slicer(double(y_k(k)), cfg.mod_type, norm_mode);
    end
    metrics.ser        = fi(sum(abs(dec_eval - double(s_k)) > 1e-4) / n_eval, 0, 16, 14);
    metrics.evm_dd_pct = 100 * (sqrt(mean(abs(double(y_k) - dec_eval).^2)) / double(rms_s));

    n_k        = (double(rx_out.str.sym_clk_idx(idx_eval)) - 3) + double(rx_out.str.mu_log(idx_eval));
    theta_true = 2 * pi * (cfg.cfo_norm / cfg.sps) * n_k + cfg.phase_offset;
    theta_nco  = 2 * pi * double(rx_out.nco_phase_log(idx_eval));

    ph_diff_rad  = angle(exp(1j * (theta_nco - theta_true)));
    bias_rad     = angle(mean(exp(1j * ph_diff_rad)));
    centered_rad = angle(exp(1j * (ph_diff_rad - bias_rad)));

    metrics.phase_bias_deg    = bias_rad * (180 / pi);
    metrics.phase_err_deg_rms = sqrt(mean(centered_rad.^2)) * (180 / pi);

    t_tail                     = double(rx_out.str.t_phase_log(idx_eval));
    metrics.timing_jitter_Ts   = std(t_tail);
    metrics.coarse_cfo_err_pct = 100 * abs(double(rx_out.coarse_cfo_est) - cfg.cfo_norm);
    metrics.fine_cfo_err_pct   = 100 * abs(double(rx_out.fine_cfo_est)   - cfg.cfo_norm);

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
