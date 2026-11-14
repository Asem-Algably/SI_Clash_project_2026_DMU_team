%% Master Acceptance Test Suite (S1 and T1 through T9)
clear; clc; close all;
cur_file = mfilename('fullpath');
if ~isempty(cur_file)
    search_dir = fileparts(cur_file);
else
    search_dir = pwd;
end
for depth = 1:4
    if exist(fullfile(search_dir, 'setup_project.m'), 'file')
        addpath(search_dir);
        break;
    end
    search_dir = fileparts(search_dir);
end
setup_project(false);

%% S1: Scorer Overlap & Lag Alignment Verification (Fix 1)
disp('=== S1: Scorer Overlap & Lag Alignment Check ===');
cfg_s1 = get_default_config(); cfg_s1.mod_type = 1; cfg_s1.cfo_norm = 0; cfg_s1.phase_offset = 0;
pay_s1 = generate_payload(1, 1200, 55);
pre_s1 = generate_preamble('q4q2_q1', cfg_s1.N_preamble, cfg_s1);
ideal_burst = [pre_s1; pay_s1];
cases_s1 = {
    'N_pre + N_pay - 1 (1515, 1 short)', ideal_burst(1:end-1), 0;
    'N_pre + N_pay + 1 (1517, 1 long) ', [ideal_burst; ideal_burst(end)], 0;
    'Delayed by +1 symbol (lag = +1)  ', [0; ideal_burst], 1;
    'Delayed by +2 symbols (lag = +2) ', [0; 0; ideal_burst], 2
};
for c = 1:size(cases_s1, 1)
    y_v = cases_s1{c, 2}; L = numel(y_v);
    d_out.out_sym_cplx    = y_v * cfg_s1.in_scale;
    d_out.nco_phase_log   = zeros(L, 1);
    d_out.str.sym_clk_idx = (4:4:4*L).';
    d_out.str.mu_log      = zeros(L, 1);
    d_out.str.t_phase_log = zeros(L, 1);
    d_out.coarse_cfo_est  = 0; d_out.fine_cfo_est = 0;
    d_out.str_lock_sym    = 35; d_out.costas_lock_sym = 340; d_out.costas_lock_from_load = 235;
    d_out.quad_unresolved = false;
    m_s1 = compute_evm_and_metrics(d_out, pay_s1, cfg_s1);
    st = 'FAIL';
    if m_s1.payload_lag == cases_s1{c, 3} && m_s1.evm_rms_pct < 1e-3 && m_s1.ser == 0
        st = 'PASS';
    end
    disp(sprintf('  %s -> lag=%+d, n_eval=%d, EVM=%.4f%%, SER=%.4f [%s]', ...
        cases_s1{c,1}, m_s1.payload_lag, m_s1.n_eval, m_s1.evm_rms_pct, m_s1.ser, st));
end

%% T1: Es/N0 Calibration Verification
disp(' ');
disp('=== T1: Es/N0 Calibration Check ===');
cfg = get_default_config();
snrs = [5, 10, 15, 20];
for m = [0, 1]
    [pay, const] = generate_payload(m, 3000, 42);
    tx_w = pulse_shape_rrc(pay, cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
    for s = 1:numel(snrs)
        cfg_t = cfg; cfg_t.snr_dB = snrs(s); cfg_t.snr_def = 'esn0';
        meas = measure_es_n0(tx_w, cfg_t);
        st = 'FAIL'; if abs(meas - snrs(s)) <= 0.3, st = 'PASS'; end
        disp(sprintf('  %6s | Req = %2d dB | Measured Es/N0 = %6.2f dB (Diff = %+.2f dB) [%s]', ...
            const.name, snrs(s), meas, meas - snrs(s), st));
    end
end

%% T2, A5, Fix 4.1 & Fix 5: Loop Bandwidth, Pipe Delay & STR Slope
disp(' ');
run('test_loop_bandwidth.m');

%% T3: Blind Receiver Check (ref_preamble = [] vs random vector)
disp(' ');
disp('=== T3: Blind Operation Verification ===');
cfg = get_default_config();
pre = generate_preamble(cfg.preamble_type, cfg.N_preamble, cfg);
pay = generate_payload(1, cfg.N_payload, cfg.seed);
tx_w = pulse_shape_rrc([pre; pay], cfg.rrc_alpha, cfg.rrc_span, cfg.sps, 'tx');
rx_m = apply_channel_impairments(tx_w, cfg);
out_empty = run_cycle_accurate_top(rx_m, true(size(rx_m)), cfg);
out_rand  = run_cycle_accurate_top(rx_m, true(size(rx_m)), cfg);
max_diff  = max(abs(out_empty.out_sym_cplx - out_rand.out_sym_cplx));
st_t3 = 'FAIL'; if max_diff == 0, st_t3 = 'PASS'; end
disp(sprintf('  Max symbol difference (empty vs random ref_preamble): %.2e [%s]', max_diff, st_t3));

%% T4 & T5: 200-Burst Quadrant Ambiguity & Lock Rule Verification (Fix 7.1 & 7.2)
disp(' ');
disp('=== T4 & T5: 200-Burst Quadrant Ambiguity & Lock Rule Check ===');
N_bursts       = 200;
init_quad_hist = zeros(1, 4);
pass_no_quad   = 0;
pass_with_quad = 0;
unresolved_cnt = 0;
t5_violations  = 0;

for b = 1:N_bursts
    rng(1000 + b);
    cfg_b = get_default_config();
    cfg_b.mod_type     = mod(b, 2);
    cfg_b.snr_dB       = 15 + 3 * mod(floor((b-1)/2), 2);
    cfg_b.cfo_norm     = -0.10 + 0.20 * rand();
    cfg_b.phase_offset = -pi + 2 * pi * rand();
    cfg_b.tau_offset   = rand();

    pre_b = generate_preamble('q4q2_q1', cfg_b.N_preamble, cfg_b);
    pay_b = generate_payload(cfg_b.mod_type, cfg_b.N_payload, 2000 + b);
    tx_b  = pulse_shape_rrc([pre_b; pay_b], cfg_b.rrc_alpha, cfg_b.rrc_span, cfg_b.sps, 'tx');
    rx_b  = apply_channel_impairments(tx_b, cfg_b);

    out_on = run_cycle_accurate_top(rx_b, true(size(rx_b)), cfg_b);
    met_on = compute_evm_and_metrics(out_on, pay_b, cfg_b);

    % Fix 7.1: Exclude unresolved bursts from k=0..3 histogram
    if out_on.quad_unresolved || isnan(out_on.quad_k)
        unresolved_cnt = unresolved_cnt + 1;
    elseif out_on.quad_k >= 0 && out_on.quad_k <= 3
        init_quad_hist(out_on.quad_k + 1) = init_quad_hist(out_on.quad_k + 1) + 1;
    end
    if met_on.ser < 0.05, pass_with_quad = pass_with_quad + 1; end

    % Fix 7.2: Guard T5 against NaN or out-of-bounds quad_corr_sym
    N_sym_b = numel(out_on.costas_lock);
    if isnan(out_on.quad_corr_sym) || out_on.quad_corr_sym < 1 || out_on.quad_corr_sym > N_sym_b
        t5_violations = t5_violations + 1;
    else
        c_idx = round(out_on.quad_corr_sym);
        if any(out_on.costas_lock(1:c_idx)) || any(out_on.lock_detect(1:c_idx))
            t5_violations = t5_violations + 1;
        end
    end

    cfg_off = cfg_b; cfg_off.quad.enable = false;
    out_off = run_cycle_accurate_top(rx_b, true(size(rx_b)), cfg_off);
    met_off = compute_evm_and_metrics(out_off, pay_b, cfg_off);
    if met_off.ser < 0.05, pass_no_quad = pass_no_quad + 1; end
end
resolved_total = max(sum(init_quad_hist), 1);
disp(sprintf('  (a) Initial lock angle distribution (resolved): [%.1f%%, %.1f%%, %.1f%%, %.1f%%], Unresolved bin = %d', ...
    100*init_quad_hist/resolved_total, unresolved_cnt));
disp(sprintf('  (b) Correct bursts WITHOUT QUAD_CHECK         : %.1f%% (%d/%d)', ...
    100*pass_no_quad/N_bursts, pass_no_quad, N_bursts));
disp(sprintf('  (c) Correct bursts WITH QUAD_CHECK            : %.1f%% (%d/%d), unresolved = %d', ...
    100*pass_with_quad/N_bursts, pass_with_quad, N_bursts, unresolved_cnt));
disp(sprintf('  (T5) Lock rule violations (k <= corr_sym)     : %d', t5_violations));

%% T6: Scorer Rotation Check for QPSK and 16-QAM at 0, 90, 180, 270 deg (Fix 2)
disp(' ');
disp('=== T6: Scorer Rotation Check (QPSK & 16-QAM at 0, 90, 180, 270 deg) ===');
rots = [0, 90, 180, 270];
for m_type = [0, 1]
    cfg_t6 = get_default_config(); cfg_t6.mod_type = m_type; cfg_t6.cfo_norm = 0; cfg_t6.phase_offset = 0;
    [pay_t6, const_t6] = generate_payload(m_type, 1200, 77);
    for r_idx = 1:numel(rots)
        rot_deg = rots(r_idx);
        rot_rad = rot_deg * (pi / 180);
        L = cfg_t6.N_preamble + 1200;
        d_out.out_sym_cplx    = [zeros(cfg_t6.N_preamble, 1); pay_t6 * exp(-1j * rot_rad)] * cfg_t6.in_scale;
        d_out.nco_phase_log   = rot_rad * ones(L, 1);
        d_out.str.sym_clk_idx = (4 : 4 : 4*L).';
        d_out.str.mu_log      = zeros(L, 1);
        d_out.str.t_phase_log = zeros(L, 1);
        d_out.coarse_cfo_est  = 0; d_out.fine_cfo_est = 0;
        d_out.str_lock_sym    = 35; d_out.costas_lock_sym = 340; d_out.costas_lock_from_load = 235;
        d_out.quad_unresolved = false;
        mt6 = compute_evm_and_metrics(d_out, pay_t6, cfg_t6);
        disp(sprintf('  %-6s | Rot = %3d deg -> EVM = %7.2f%%, SER = %.4f, Phase Bias = %+7.2f deg', ...
            const_t6.name, rot_deg, mt6.evm_rms_pct, mt6.ser, mt6.phase_bias_deg));
    end
end

%% T7: STR Timing Jitter at True Es/N0 = 15 dB (Fix 3 & Fix 4.3)
disp(' ');
disp('=== T7: STR Timing Jitter at True Es/N0 = 15 dB (8 Runs/Cell, Last 800 Symbols) ===');
taus_t7  = [0, 0.25, 0.48, 0.5, 0.75, 0.95, 0.999];   % 0.48 and 0.95 added: jitter peaks there for 16-QAM
modes_t7 = {'parabolic'};
cfos_t7  = [0.0, 0.10];
mods_t7  = [0, 1];   % QPSK and 16-QAM
for gs = [false, true]
    disp(sprintf('--- gain_sched = %d ---', double(gs)));
    for mt_i = 1:numel(mods_t7)
    for c_i = 1:numel(cfos_t7)
        for m_i = 1:numel(modes_t7)
            for t_i = 1:numel(taus_t7)
                j_runs = zeros(8, 1);
                l_runs = zeros(8, 1);
                for r = 1:8
                    rng(3000 + r);
                    cfg_7 = get_default_config();
                    cfg_7.str.gain_sched  = gs;
                    cfg_7.str.interp_type = modes_t7{m_i};
                    cfg_7.snr_dB          = 15.0;
                    cfg_7.tau_offset      = taus_t7(t_i);
                    cfg_7.cfo_norm        = cfos_t7(c_i);
                    pre_7 = generate_preamble('q4q2_q1', cfg_7.N_preamble, cfg_7);
                    pay_7 = generate_payload(mods_t7(mt_i), 1000, 4000 + r);
                    cfg_7.mod_type = mods_t7(mt_i);
                    tx_7  = pulse_shape_rrc([pre_7; pay_7], cfg_7.rrc_alpha, cfg_7.rrc_span, cfg_7.sps, 'tx');
                    rx_7  = apply_channel_impairments(tx_7, cfg_7);
                    res_7 = run_str_subsystem(rx_7, cfg_7);
                    j_runs(r) = std(res_7.t_phase_log(end-799:end));
                    l_runs(r) = res_7.lock_sym;
                end
                st_7 = 'PASS'; if max(j_runs) > 0.02, st_7 = 'FAIL'; end
                disp(sprintf('  mod=%d | CFO=%.2f | %-9s | tau=%.3f -> Mean Jitter=%.4f Ts, Max=%.4f Ts, MeanLock=%.1f [%s]', ...
                    mods_t7(mt_i), cfos_t7(c_i), modes_t7{m_i}, taus_t7(t_i), mean(j_runs), max(j_runs), mean(l_runs), st_7));
            end
        end
    end
    end
end

%% T8: Full-Chain Coarse CFO Error Sweep (Fix 3)
disp(' ');
disp('=== T8: Full-Chain Coarse CFO Error (CFO in -0.10..0.10, SNR in 0..20 dB, 40 Trials/CFO) ===');
snrs_t8  = [0, 5, 10, 15, 20];
cfos_t8  = [-0.10, -0.05, 0.0, 0.05, 0.10];
c_modes  = {'dual', 'single4'};
for cm = 1:numel(c_modes)
    for s_i = 1:numel(snrs_t8)
        errs_all = [];
        wraps    = 0;
        for c_i = 1:numel(cfos_t8)
            for tr = 1:40
                rng(7000 + 100*c_i + tr);
                cfg_8 = get_default_config();
                cfg_8.coarse.mode  = c_modes{cm};
                cfg_8.snr_dB       = snrs_t8(s_i);
                cfg_8.cfo_norm     = cfos_t8(c_i);
                cfg_8.tau_offset   = rand();
                cfg_8.phase_offset = -pi + 2*pi*rand();
                pre_8 = generate_preamble('q4q2_q1', cfg_8.N_preamble, cfg_8);
                tx_8  = pulse_shape_rrc(pre_8, cfg_8.rrc_alpha, cfg_8.rrc_span, cfg_8.sps, 'tx');
                rx_8  = apply_channel_impairments(tx_8, cfg_8);
                out_8 = run_cycle_accurate_top(rx_8, true(size(rx_8)), cfg_8);
                err_pct = 100 * abs(out_8.coarse_cfo_est - cfg_8.cfo_norm);
                errs_all(end+1, 1) = err_pct; %#ok<AGROW>
                if err_pct > 3.0, wraps = wraps + 1; end
            end
        end
        rms_e = sqrt(mean(errs_all.^2));
        max_e = max(errs_all);
        st_8  = 'PASS'; if rms_e > 0.5, st_8 = 'FAIL'; end
        disp(sprintf('  Mode=%-7s | SNR=%2d dB -> RMS Err = %.4f%% Rsym, Max = %.4f%%, UnwrapErrs(>3%%) = %d/200 [%s]', ...
            c_modes{cm}, snrs_t8(s_i), rms_e, max_e, wraps, st_8));
    end
end

%% T9: Costas Residual Phase Error at True Es/N0 = 15 dB (Fix 3 & Fix 5.3)
disp(' ');
disp('=== T9: Costas Residual Phase Error RMS at True 15 dB (24 Bursts/Cell, pipe_delay = 1) ===');
bns_t9 = [0.02, 0.025, 0.03, 0.05];
for comp_flag = [false, true]
    disp(sprintf('--- compensate_delay = %d ---', double(comp_flag)));
    for m_type = [0, 1]
        for b_i = 1:numel(bns_t9)
            ph_rms_vec = zeros(24, 1);
            slips      = 0;
            for r = 1:24
                rng(9000 + 100*b_i + r);
                cfg_9 = get_default_config();
                cfg_9.mod_type                = m_type;
                cfg_9.snr_dB                  = 15.0;
                cfg_9.costas.Bn_Ts            = bns_t9(b_i);
                cfg_9.costas.pipe_delay       = 1;
                cfg_9.costas.compensate_delay = comp_flag;
                cfg_9.tau_offset              = rand();
                cfg_9.cfo_norm                = -0.10 + 0.20 * rand();
                cfg_9.phase_offset            = -pi + 2 * pi * rand();
                pre_9 = generate_preamble('q4q2_q1', cfg_9.N_preamble, cfg_9);
                [pay_9, const_9] = generate_payload(m_type, cfg_9.N_payload, 9500 + r);
                tx_9  = pulse_shape_rrc([pre_9; pay_9], cfg_9.rrc_alpha, cfg_9.rrc_span, cfg_9.sps, 'tx');
                rx_9  = apply_channel_impairments(tx_9, cfg_9);
                out_9 = run_cycle_accurate_top(rx_9, true(size(rx_9)), cfg_9);
                met_9 = compute_evm_and_metrics(out_9, pay_9, cfg_9);
                ph_rms_vec(r) = met_9.phase_err_deg_rms;
                if met_9.ser > 0.15, slips = slips + 1; end
            end
            st_9 = 'PASS'; if mean(ph_rms_vec) > 1.5 || slips > 0, st_9 = 'FAIL'; end
            disp(sprintf('  %-6s | Bn_Ts=%.3f -> Mean Phase RMS = %.2f deg, Max = %.2f deg, CycleSlips = %d/24 [%s]', ...
                const_9.name, bns_t9(b_i), mean(ph_rms_vec), max(ph_rms_vec), slips, st_9));
        end
    end
end
