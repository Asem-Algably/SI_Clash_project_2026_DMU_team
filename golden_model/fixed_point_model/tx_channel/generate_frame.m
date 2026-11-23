function [rx_samples_fi, tx_payload_fi, frame_info] = generate_frame(cfg)
    % GENERATE_FRAME  Self-contained Frame & Physical Channel Impairment Generator.
    %
    % Generates 190-symbol preamble + N_payload constellation symbols in pure fi,
    % shapes through TX RRC filter, applies channel physics (timing delay, CFO,
    % phase offset, AWGN), applies RX matched filter, clips to [-2, 2-2^-11],
    % and applies /2 front-end scaling to produce signed 12-bit Q1.11 ADC samples.

    if isfield(cfg, 'seed') && ~isempty(cfg.seed)
        rng(cfg.seed);
    end

    sps = cfg.sps;

    % =====================================================================
    % 1. PREAMBLE GENERATION (190 SYMBOLS, PURE fi sQ1.14)
    % =====================================================================
    % Phase A1 (STR)        : 70 syms alternating Q4/Q2
    % Phase A2 (Coarse CFO) : 40 syms alternating Q4/Q2
    % Phase B  (Costas Pull): 30 syms alternating Q4/Q2
    % Phase C  (Quadrant)   : 50 syms sequence [Q1, Q2, Q1, Q4]
    N_alt = cfg.preamble.N_A + cfg.preamble.N_cfo + cfg.preamble.N_B; % 140
    n_alt = (0 : N_alt - 1).';
    pre_alt = (1.0 - 1j) .* ((-1.0).^n_alt); % alternating (1-1j) and (-1+1j)

    pat_c = [1.0 + 1j; -1.0 + 1j; 1.0 + 1j; 1.0 - 1j]; % [Q1, Q2, Q1, Q4]
    N_c   = cfg.preamble.N_C; % 50
    rep_c = ceil(N_c / 4);
    pre_c = repmat(pat_c, rep_c, 1);
    pre_c = pre_c(1:N_c);

    preamble_raw = [pre_alt; pre_c];
    preamble_fi  = fi(preamble_raw, 1, 16, 14);

    % =====================================================================
    % 2. PAYLOAD GENERATION (N_payload SYMBOLS, PURE fi sQ1.14)
    % =====================================================================
    N_pay = cfg.N_payload;
    if cfg.mod_type == 0
        % QPSK (Peak Normalized: +-1 +- 1j)
        qpsk_levels = [-1.0, 1.0];
        re_idx = randi([1, 2], N_pay, 1);
        im_idx = randi([1, 2], N_pay, 1);
        payload_raw = qpsk_levels(re_idx).' + 1j * qpsk_levels(im_idx).';
    else
        % 16-QAM (Peak Normalized: +-1/3, +-1)
        qam16_levels = [-1.0, -1.0/3.0, 1.0/3.0, 1.0];
        re_idx = randi([1, 4], N_pay, 1);
        im_idx = randi([1, 4], N_pay, 1);
        payload_raw = qam16_levels(re_idx).' + 1j * qam16_levels(im_idx).';
    end
    tx_payload_fi = fi(payload_raw, 1, 16, 14);

    tx_symbols_fi = [preamble_fi; tx_payload_fi];

    % =====================================================================
    % 3. TX RRC PULSE SHAPING FILTER
    % =====================================================================
    h_rrc_raw = rcosdesign(cfg.rrc_alpha, cfg.rrc_span, sps, 'sqrt');
    h_rrc_fi  = fi(h_rrc_raw, 1, 16, 15);

    N_syms = numel(tx_symbols_fi);
    up_sig = complex(zeros(N_syms * sps, 1));
    up_sig(1 : sps : end) = double(tx_symbols_fi) * sqrt(sps);
    tx_shaped = conv(up_sig, double(h_rrc_fi), 'same');

    % =====================================================================
    % 4. CONTINUOUS PHYSICAL CHANNEL IMPAIRMENTS
    % =====================================================================
    N_ch = numel(tx_shaped);
    pad  = cfg.rrc_span * sps;

    % Fractional Timing Delay (FFT-based zero-padded linear phase)
    tx_padded     = [zeros(pad, 1); tx_shaped; zeros(pad, 1)];
    N_pad         = numel(tx_padded);
    delay_samples = cfg.tau_offset * sps;
    k_freq        = [0 : ceil(N_pad/2)-1, -floor(N_pad/2) : -1].' / N_pad;
    rx_del_pad    = ifft(fft(tx_padded) .* exp(-1j * 2 * pi * k_freq * delay_samples));
    rx_delayed    = rx_del_pad(pad + 1 : pad + N_ch);

    % Carrier Frequency Offset (CFO) & Initial Carrier Phase Offset
    n_vec     = (0 : N_ch - 1).';
    phase_vec = 2 * pi * (cfg.cfo_norm / sps) * n_vec + cfg.phase_offset;
    rx_rot    = rx_delayed .* exp(1j * phase_vec);

    % Complex Additive White Gaussian Noise (AWGN)
    sig_pwr   = mean(abs(rx_rot(pad + 1 : max(N_ch - pad, pad + 1))).^2);
    snr_lin   = 10^(cfg.snr_dB / 10);
    if strcmpi(cfg.snr_def, 'sample')
        noise_pwr = sig_pwr / snr_lin;
    else
        noise_pwr = (sig_pwr * sps) / snr_lin;
    end
    noise_raw = sqrt(noise_pwr / 2) * (randn(N_ch, 1) + 1j * randn(N_ch, 1));
    rx_noisy  = rx_rot + noise_raw;

    % RX Matched RRC Filter
    rx_matched_raw = conv(rx_noisy, double(h_rrc_fi) / sqrt(sps), 'same');

    % =====================================================================
    % 5. FRONT-END HARD CLIPPING & /2 ADC SCALING
    % =====================================================================
    clip_lim = 2.0 - 2^(-11); % 1.99951171875
    rx_re = min(max(real(rx_matched_raw), -2.0), clip_lim);
    rx_im = min(max(imag(rx_matched_raw), -2.0), clip_lim);

    % Scale by 0.5 into [-1, 1 - 2^-12]
    rx_re_scaled = rx_re * cfg.in_scale;
    rx_im_scaled = rx_im * cfg.in_scale;

    % Quantize into signed 12-bit Q1.11 fi
    rx_samples_fi = complex(fi(rx_re_scaled, 1, 12, 11), fi(rx_im_scaled, 1, 12, 11));

    % Save frame info metadata
    frame_info.N_preamble    = cfg.N_preamble;
    frame_info.N_payload     = N_pay;
    frame_info.tx_symbols_fi = tx_symbols_fi;
    frame_info.measured_esn0 = 10 * log10(sig_pwr / (noise_pwr / sps));
    frame_info.sig_pwr       = sig_pwr;
    frame_info.noise_pwr     = noise_pwr;
end
