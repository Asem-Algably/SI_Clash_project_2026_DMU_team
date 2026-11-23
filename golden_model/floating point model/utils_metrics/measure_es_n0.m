function es_n0_dB = measure_es_n0(tx_waveform, cfg)
    % Measures true Es/N0 (dB) at the symbol instants of the RX matched-filter output.
    % Note (Fix 7.3): Forces tau_offset = 0, cfo_norm = 0, and phase_offset = 0 in a
    % local copy of cfg so signal and noise power are sampled at exact symbol peaks.
    cfg_eval              = cfg;
    cfg_eval.tau_offset   = 0.0;
    cfg_eval.cfo_norm     = 0.0;
    cfg_eval.phase_offset = 0.0;

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
