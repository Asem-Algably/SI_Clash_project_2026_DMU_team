function es_n0_dB = measure_es_n0(tx_waveform, cfg)
    % MEASURE_ES_N0  True unclipped Es/N0 (dB) at symbol sampling instants.
    % Evaluates signal-to-noise ratio at the output of the receiver matched filter
    % without quantization or clipping artifacts to obtain true channel SNR.

    cfg_eval              = cfg;
    cfg_eval.tau_offset   = 0.0;
    cfg_eval.cfo_norm     = 0.0;
    cfg_eval.phase_offset = 0.0;
    cfg_eval.quantize_q11 = false;

    cfg_clean        = cfg_eval;
    cfg_clean.snr_dB = Inf;

    sig_out   = apply_channel_impairments(tx_waveform, cfg_clean);
    rx_out    = apply_channel_impairments(tx_waveform, cfg_eval);
    noise_out = rx_out - sig_out;

    sps     = cfg_eval.sps;
    margin  = cfg_eval.rrc_span * sps;
    idx_sym = (1 + margin) : sps : (numel(sig_out) - margin);

    sig_syms   = sig_out(idx_sym);
    noise_syms = noise_out(idx_sym);

    es_n0_dB = 10 * log10(mean(abs(sig_syms).^2) / mean(abs(noise_syms).^2));
end
