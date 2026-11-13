function [rx_in_q11, ch_info] = apply_channel_impairments(tx_waveform, cfg)
    % Physical Channel & Front-End ADC Model:
    %   1. Zero-padded FFT fractional timing delay (tau_offset * sps).
    %   2. Carrier frequency offset (cfo_norm) and initial carrier phase rotation.
    %   3. Complex AWGN added from measured channel signal power ('sample' or 'esn0').
    %   4. RX matched Root-Raised Cosine (RRC) filter.
    %   5. Front-end /2 scaling (in_scale = 0.5, mapping QPSK range 2 and 16-QAM range 6 into [-1, +1))
    %      followed by ADC Q1.11 quantization and hard clipping to [-1, 1 - 2^-11].

    tx_waveform = double(tx_waveform(:));
    sps = cfg.sps;
    N   = numel(tx_waveform);
    pad = cfg.rrc_span * sps;

    % 1. Zero-padded FFT Fractional Timing Delay
    tx_padded     = [zeros(pad, 1); tx_waveform; zeros(pad, 1)];
    N_pad         = numel(tx_padded);
    delay_samples = cfg.tau_offset * sps;
    k_freq        = [0:ceil(N_pad/2)-1, -floor(N_pad/2):-1].' / N_pad;
    rx_del_pad    = ifft(fft(tx_padded) .* exp(-1j * 2 * pi * k_freq * delay_samples));
    rx_delayed    = rx_del_pad(pad + 1 : pad + N);

    % 2. Carrier Frequency Offset (CFO) & Phase Offset BEFORE RX RRC filter
    n_Grid    = (0:N-1).';
    phase_vec = 2 * pi * (cfg.cfo_norm / sps) * n_Grid + cfg.phase_offset;
    rx_rot    = rx_delayed .* exp(1j * phase_vec);

    % 3. Add White Complex Gaussian Noise from MEASURED signal power
    sig_pwr = mean(abs(rx_rot(pad + 1 : max(N - pad, pad + 1))).^2);
    if isfinite(cfg.snr_dB)
        snr_lin = 10^(cfg.snr_dB / 10);
        snr_def = 'sample';
        if isfield(cfg, 'snr_def')
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

    % 5. Channel Clipping to [-2, 2 - 2^-11] before External Front-End /2 Scaling
    scale_q11  = 2048; % 2^11
    clip_min   = -2.0;
    clip_max   = 2.0 - (1.0 / scale_q11);
    re_matched = double(real(rx_matched));
    im_matched = double(imag(rx_matched));
    rx_re_cl   = min(max(re_matched, clip_min), clip_max);
    rx_im_cl   = min(max(im_matched, clip_min), clip_max);
    clip_count = sum((re_matched < clip_min) | (re_matched > clip_max)) + ...
                 sum((im_matched < clip_min) | (im_matched > clip_max));

    % External Front-End /2 Scaling (in_scale = 0.5) mapping into [-1, 1 - 2^-12]
    in_scale = 0.5;
    if isfield(cfg, 'in_scale')
        in_scale = cfg.in_scale;
    end
    rx_scaled = complex(rx_re_cl * in_scale, rx_im_cl * in_scale);

    % ADC output as pure fixed-point fi array: signed 12-bit Q1.11
    rx_in_q11 = fi(rx_scaled, 1, 12, 11);

    ch_info.sig_pwr        = sig_pwr;
    ch_info.peak_axis      = max(max(abs(real(rx_scaled))), max(abs(imag(rx_scaled))));
    ch_info.q11_clip_count = clip_count;
    ch_info.q11_rms_cplx   = sqrt(mean(abs(rx_in_q11).^2));
    ch_info.q11_rms_axis   = sqrt(0.5 * mean(abs(rx_in_q11).^2));
    ch_info.q11_max_abs    = max(max(abs(real(rx_in_q11))), max(abs(imag(rx_in_q11))));
end
