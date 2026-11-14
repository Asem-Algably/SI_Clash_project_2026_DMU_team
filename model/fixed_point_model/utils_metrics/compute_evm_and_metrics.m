function metrics = compute_evm_and_metrics(rx_out, tx_payload_fi, cfg, measured_esn0_dB)
    % COMPUTE_EVM_AND_METRICS  Fixed-Point EVM & Performance Metric Scorer.
    %
    % Scales output by * 2 (restoring original scale), evaluates strictly on the
    % payload symbols post-lock (excluding preamble), and computes:
    %   - Excess EVM (primary metric): sqrt(max(EVM_total^2 - EVM_floor^2, 0))
    %   - Total EVM (RMS) and Floor EVM
    %   - Symbol Error Rate (SER)
    %
    % Inputs:
    %   rx_out            - Synchronizer output struct from run_cycle_accurate_top
    %   tx_payload_fi     - Reference transmitted payload symbols
    %   cfg               - Synchronizer hardware configuration struct
    %   measured_esn0_dB  - (Optional) Measured Es/N0 in dB. If omitted, computed from cfg.

    tx_payload = tx_payload_fi(:);
    y_raw      = rx_out.out_sym_cplx(:);

    % Restore Outer System Scale (* 2)
    y_all = fi(2.0 * double(y_raw), 1, 16, 14);

    N_total = numel(y_all);
    N_pay   = numel(tx_payload);
    N_pre   = cfg.N_preamble; % 190

    % Exclude preamble and evaluate strictly after lock is declared
    lock_sym_idx = N_pre + 1;
    if isfield(rx_out, 'costas_lock_sym') && ~isnan(rx_out.costas_lock_sym) && (rx_out.costas_lock_sym > 0)
        lock_sym_idx = max(lock_sym_idx, round(rx_out.costas_lock_sym));
    elseif isfield(rx_out, 'lock_detect') && any(rx_out.lock_detect)
        lock_sym_idx = max(lock_sym_idx, find(rx_out.lock_detect, 1, 'first'));
    end

    start_pay_idx = max(1, lock_sym_idx - N_pre);
    if start_pay_idx > N_pay
        start_pay_idx = 1;
    end

    pay_idx  = start_pay_idx : N_pay;
    idx_eval = N_pre + pay_idx;

    valid_mask = (idx_eval >= 1) & (idx_eval <= N_total) & (pay_idx >= 1) & (pay_idx <= N_pay);
    pay_idx    = pay_idx(valid_mask);
    idx_eval   = idx_eval(valid_mask);

    if isempty(pay_idx)
        n_fb     = min(50, min(N_total, N_pay));
        pay_idx  = (N_pay - n_fb + 1) : N_pay;
        idx_eval = (N_total - n_fb + 1) : N_total;
    end

    n_eval = numel(pay_idx);
    s_k    = tx_payload(pay_idx);
    y_k    = y_all(idx_eval);

    % =====================================================================
    % FIXED-POINT EVM COMPUTATION (32-Bit Error Accumulator)
    % =====================================================================
    e_k   = y_k - s_k;
    e_re  = real(e_k);
    e_im  = imag(e_k);
    e_sq  = double(e_re).^2 + double(e_im).^2;
    sum_e = sum(fi(e_sq, 0, 32, 28));
    rms_e = sqrt(fi(sum_e / n_eval, 0, 32, 28));

    s_re  = real(s_k);
    s_im  = imag(s_k);
    s_sq  = double(s_re).^2 + double(s_im).^2;
    sum_s = sum(fi(s_sq, 0, 32, 28));
    rms_s = sqrt(fi(sum_s / n_eval, 0, 32, 28));

    % Es/N0 and Theoretical Floor EVM
    if nargin >= 4 && ~isempty(measured_esn0_dB) && isfinite(measured_esn0_dB)
        esn0_dB = double(measured_esn0_dB);
    elseif isfield(cfg, 'snr_def') && strcmpi(cfg.snr_def, 'sample')
        esn0_dB = cfg.snr_dB + 10 * log10(cfg.sps);
    else
        esn0_dB = cfg.snr_dB;
    end
    floor_pct_d = 100.0 * (10^(-esn0_dB / 20.0));

    % Format as 16-Bit Q8.8 Fixed-Point Percentages
    tot_pct_d = (double(rms_e) / double(rms_s)) * 100.0;
    exc_pct_d = sqrt(max(tot_pct_d^2 - floor_pct_d^2, 0.0));

    metrics.evm_excess_pct = fi(exc_pct_d,   0, 16, 8);
    metrics.evm_total_pct  = fi(tot_pct_d,   0, 16, 8);
    metrics.evm_floor_pct  = fi(floor_pct_d, 0, 16, 8);
    metrics.n_eval         = n_eval;
    metrics.esn0_dB        = esn0_dB;

    % =====================================================================
    % SYMBOL ERROR RATE (SER)
    % =====================================================================
    dec_syms = complex(zeros(n_eval, 1));
    for k = 1:n_eval
        yk_d = double(y_k(k));
        if cfg.mod_type == 0
            % QPSK Slicing (+-1 +- 1j)
            dr = sign(real(yk_d)); if dr == 0, dr = 1; end
            di = sign(imag(yk_d)); if di == 0, di = 1; end
            dec_syms(k) = dr + 1j * di;
        else
            % 16-QAM Slicing (+-1/3, +-1 with thresholds 0, +-2/3)
            dec_syms(k) = slice_qam16_pt(yk_d);
        end
    end
    err_cnt     = sum(abs(dec_syms - double(s_k)) > 0.1);
    metrics.ser = fi(err_cnt / n_eval, 0, 16, 14);

    % Additional Synchronizer Metrics
    metrics.coarse_cfo_err = abs(double(rx_out.coarse_cfo_est) - cfg.cfo_norm);
    metrics.fine_cfo_err   = abs(double(rx_out.fine_cfo_est)   - cfg.cfo_norm);
    metrics.str_lock_sym   = rx_out.str_lock_sym;
    metrics.costas_lock_sym= rx_out.costas_lock_sym;

    % Timing Jitter (RMS in symbol periods Ts, R.111 target <= 0.02 Ts)
    if isfield(rx_out, 'str') && isfield(rx_out.str, 't_phase_log') && ~isempty(rx_out.str.t_phase_log)
        t_tail = double(rx_out.str.t_phase_log(idx_eval));
        metrics.timing_jitter_Ts = std(t_tail);
    else
        metrics.timing_jitter_Ts = NaN;
    end
    metrics.pass_str_jitter = (metrics.timing_jitter_Ts <= 0.0200);
end

function a = slice_qam16_pt(y)
    yr = real(y);
    yi = imag(y);
    ar = slice_1d_pt(yr);
    ai = slice_1d_pt(yi);
    a  = ar + 1j * ai;
end

function a = slice_1d_pt(x)
    if x >= (2.0 / 3.0)
        a = 1.0;
    elseif x >= 0
        a = 1.0 / 3.0;
    elseif x >= -(2.0 / 3.0)
        a = -1.0 / 3.0;
    else
        a = -1.0;
    end
end
