function [rx_in_q11, ch_info] = apply_channel_impairments(tx_waveform, cfg)
    % Part 1a, 1b, 1c, 0c, 0e Physical Channel Model:
    % 1. Zero-padded FFT fractional delay (padded by rrc_span*sps on both ends, trimmed after).
    % 2. CFO & phase rotation applied BEFORE the RX matched RRC filter.
    % 3. White complex noise added from MEASURED channel signal power (supports cfg.snr_def = 'esn0' | 'sample').
    % 4. RX matched RRC filter applied to signal and noise together.
    % 5. Fixed design headroom cfg.input_headroom applied before signed 12-bit Q1.11 quantisation + clip counter.

    tx_waveform = tx_waveform(:);
    sps = cfg.sps;
    N   = numel(tx_waveform);
    pad = cfg.rrc_span * sps;

    % 1. Zero-padded FFT Fractional Timing Delay (Part 1c)
    tx_padded     = [zeros(pad, 1); tx_waveform; zeros(pad, 1)];
    N_pad         = numel(tx_padded);
    delay_samples = cfg.tau_offset * sps;
    k_freq        = [0:ceil(N_pad/2)-1, -floor(N_pad/2):-1].' / N_pad;
    rx_del_pad    = ifft(fft(tx_padded) .* exp(-1j * 2 * pi * k_freq * delay_samples));
    rx_delayed    = rx_del_pad(pad + 1 : pad + N);

    % 2. Carrier Frequency Offset (CFO) & Phase Offset BEFORE RX RRC filter (Part 1a)
    n_Grid    = (0:N-1).';
    phase_vec = 2 * pi * (cfg.cfo_norm / sps) * n_Grid + cfg.phase_offset;
    rx_rot    = rx_delayed .* exp(1j * phase_vec);

    % 3. Add White Complex Gaussian Noise from MEASURED signal power (Part 0e & 1b)
    sig_pwr = mean(abs(rx_rot(pad + 1 : max(N - pad, pad + 1))).^2);
    if isfinite(cfg.snr_dB)
        snr_lin = 10^(cfg.snr_dB / 10);
        snr_def = 'esn0';
        if isfield(cfg, 'snr_def') && ~isempty(cfg.snr_def)
            snr_def = cfg.snr_def;
        end
        if strcmpi(snr_def, 'sample')
            noise_pwr = sig_pwr / snr_lin;
        elseif strcmpi(snr_def, 'esn0')
            noise_pwr = (sig_pwr * sps) / snr_lin;
        else
            error('Unknown cfg.snr_def: %s. Use ''esn0'' or ''sample''.', snr_def);
        end
        raw_noise = sqrt(noise_pwr / 2) * (randn(N, 1) + 1j * randn(N, 1));
        rx_noisy  = rx_rot + raw_noise;
    else
        rx_noisy  = rx_rot;
    end

    % 4. RX Matched Root-Raised Cosine (RRC) Filter
    rx_matched = pulse_shape_rrc(rx_noisy, cfg.rrc_alpha, cfg.rrc_span, sps, 'rx');

    % 5. Part 0c: Apply fixed cfg.input_headroom and quantise to signed Q1.11 (12-bit)
    headroom = 0.22;
    if isfield(cfg, 'input_headroom') && ~isempty(cfg.input_headroom)
        headroom = cfg.input_headroom;
    end
    rx_scaled = rx_matched * headroom;

    do_q11 = true;
    if isfield(cfg, 'quantize_q11')
        do_q11 = cfg.quantize_q11;
    end

    if do_q11
        scale_q11  = 2048; % 2^11
        q_min      = -1.0;
        q_max      = 1.0 - (1.0 / scale_q11);
        re_q       = round(real(rx_scaled) * scale_q11) / scale_q11;
        im_q       = round(imag(rx_scaled) * scale_q11) / scale_q11;
        clip_count = sum((re_q < q_min) | (re_q > q_max)) + sum((im_q < q_min) | (im_q > q_max));
        rx_in_q11  = min(max(re_q, q_min), q_max) + 1j * min(max(im_q, q_min), q_max);
    else
        rx_in_q11  = rx_scaled;
        clip_count = 0;
    end

    ch_info.sig_pwr        = sig_pwr;
    ch_info.input_headroom = headroom;
    ch_info.q11_clip_count = clip_count;
    ch_info.q11_rms_cplx   = sqrt(mean(abs(rx_in_q11).^2));
    ch_info.q11_rms_axis   = sqrt(0.5 * mean(abs(rx_in_q11).^2));
    ch_info.q11_max_abs    = max(max(abs(real(rx_in_q11))), max(abs(imag(rx_in_q11))));
end
