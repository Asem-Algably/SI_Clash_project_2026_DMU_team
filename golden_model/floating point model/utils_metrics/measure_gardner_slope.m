function slopes = measure_gardner_slope(cfg)
    % Part 0d: Measures open-loop Gardner TED slope K_ted around the stable lock point
    % for QPSK payload, 16-QAM payload, and the alternating Phase A/B preamble AT THE
    % ADOPTED CONSTELLATION SCALE (cfg.norm_mode).
    cfg_m              = cfg;
    cfg_m.snr_dB       = Inf;
    cfg_m.cfo_norm     = 0.0;
    cfg_m.phase_offset = 0.0;
    cfg_m.quantize_q11 = false;
    cfg_m.str.open_loop          = true;
    cfg_m.str.mu_bits            = 0;

    labels = {'Kp_ted_qpsk', 'Kp_ted_16qam', 'Kp_ted_preamble'};
    for idx = 1:3
        if idx == 1
            syms_in = generate_payload(0, 3000, 42, cfg_m.norm_mode);
        elseif idx == 2
            syms_in = generate_payload(1, 3000, 42, cfg_m.norm_mode);
        else
            pre_full = generate_preamble('q4q2_q1', 268, cfg_m);
            syms_in  = pre_full(1:260);
        end
        tx_w = pulse_shape_rrc(syms_in, cfg_m.rrc_alpha, cfg_m.rrc_span, cfg_m.sps, 'tx');
        e_pair = zeros(1, 2);
        dts    = [-0.01, 0.01];
        for k = 1:2
            cfg_m.tau_offset = 0.25 + dts(k);
            rx_q11 = apply_channel_impairments(tx_w, cfg_m);
            res_s  = run_str_subsystem(rx_q11, cfg_m);
            e_pair(k) = mean(res_s.ted_log(21:end-20));
        end
        slopes.(labels{idx}) = -(e_pair(2) - e_pair(1)) / 0.02;
    end
end
